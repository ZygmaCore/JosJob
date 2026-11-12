defmodule StellarJob.Listings do
  @moduledoc "Scoped job browsing and employer writes using the existing organization RBAC."
  require Ash.Query
  alias Stellar.Authz
  alias StellarJob.Job

  @fields ~w(title description location industry employment_type work_mode requirements highlights salary_min salary_max currency status)
  @types ~w(full-time part-time internship contract freelance)
  @modes ~w(remote hybrid onsite)
  @statuses ~w(draft active expired)

  def organizations(user) do
    orgs =
      if Authz.superuser?(user) do
        Stellar.Orgs.Organization
        |> Ash.Query.sort(name: :asc)
        |> Ash.read!(authorize?: false)
        |> Enum.map(&%{id: &1.id, name: &1.name})
      else
        Authz.member_orgs(user)
      end

    Enum.map(orgs, fn org ->
      permissions = Authz.permissions_for(user, org.id)
      admin? = user.is_superuser
      post? = admin? or MapSet.member?(permissions, "jobs:post")
      manage? = admin? or MapSet.member?(permissions, "jobs:manage")

      Map.merge(org, %{
        can_post: post?,
        can_manage: manage?,
        can_read: post? or manage? or MapSet.member?(permissions, "jobs:read")
      })
    end)
    |> Enum.filter(& &1.can_read)
  end

  def list(user, params) do
    orgs = organizations(user)

    with {:ok, filters} <- filters(params) do
      org_ids =
        for org <- orgs, filters.scope == "browse" or org.can_manage or org.can_post, do: org.id

      query = Ash.Query.filter(Job, organization_id in ^org_ids)

      query =
        if filters.scope == "browse", do: Ash.Query.filter(query, status == "active"), else: query

      query = apply_filters(query, filters)

      with {:ok, total} <- Ash.count(query, authorize?: false),
           {:ok, jobs} <-
             query
             |> Ash.Query.sort(sort(filters.sort))
             |> Ash.Query.limit(filters.page_size)
             |> Ash.Query.offset((filters.page - 1) * filters.page_size)
             |> Ash.Query.load(:organization)
             |> Ash.read(authorize?: false) do
        {:ok,
         %{
           jobs: jobs,
           organizations: orgs,
           meta: %{
             page: filters.page,
             page_size: filters.page_size,
             total: total,
             total_pages: ceil(total / filters.page_size)
           }
         }}
      end
    end
  end

  def get(user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {:ok, job} <- Ash.get(Job, id, load: :organization, authorize?: false),
         true <- visible?(user, job) do
      {:ok, job}
    else
      _ -> {:error, :not_found}
    end
  end

  def create(user, org_id, params) do
    with {:ok, org_id} <- Ecto.UUID.cast(org_id),
         true <- Authz.can?(user, org_id, "jobs:post"),
         {:ok, job} <-
           Job
           |> Ash.Changeset.for_create(:create, attributes(params))
           |> Ash.Changeset.force_change_attribute(:organization_id, org_id)
           |> Ash.Changeset.force_change_attribute(:created_by, user.id)
           |> stamp_publication()
           |> Ash.create(authorize?: false) do
      Ash.load(job, :organization, authorize?: false)
    else
      :error -> {:error, :forbidden}
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def update(user, id, params) do
    with {:ok, job} <- get(user, id),
         true <- Authz.can?(user, job.organization_id, "jobs:manage"),
         {:ok, updated} <-
           job
           |> Ash.Changeset.for_update(:update, attributes(params))
           |> stamp_publication()
           |> Ash.update(authorize?: false) do
      Ash.load(updated, :organization, authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def delete(user, id) do
    with {:ok, job} <- get(user, id),
         true <- Authz.can?(user, job.organization_id, "jobs:manage") do
      Ash.destroy(job, authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp visible?(_user, nil), do: false

  defp visible?(user, job) do
    Enum.any?(organizations(user), fn org ->
      org.id == job.organization_id and (job.status == "active" or org.can_manage or org.can_post)
    end)
  end

  defp attributes(params) do
    params
    |> Map.take(@fields)
    |> Map.new(fn
      {key, value} when is_binary(value) -> {key, String.trim(value)}
      pair -> pair
    end)
  end

  defp stamp_publication(changeset) do
    if Ash.Changeset.get_attribute(changeset, :status) == "active" and
         is_nil(Ash.Changeset.get_attribute(changeset, :posted_at)) do
      Ash.Changeset.force_change_attribute(changeset, :posted_at, DateTime.utc_now())
    else
      changeset
    end
  end

  defp filters(params) do
    with {:ok, page} <- integer(params, "page", 1, 1, 10_000),
         {:ok, size} <- integer(params, "page_size", 12, 1, 50),
         {:ok, salary} <- integer(params, "salary_min", nil, 0, 1_000_000_000_000),
         {:ok, type} <- choice(params, "employment_type", [""] ++ @types, ""),
         {:ok, mode} <- choice(params, "work_mode", [""] ++ @modes, ""),
         {:ok, scope} <- choice(params, "scope", ~w(browse manage), "browse"),
         {:ok, sort} <- choice(params, "sort", ~w(newest salary), "newest"),
         {:ok, status} <- choice(params, "status", [""] ++ @statuses, ""),
         {:ok, search} <- text(params, "q"),
         {:ok, industry} <- text(params, "industry"),
         {:ok, location} <- text(params, "location"),
         {:ok, currency} <- text(params, "currency"),
         :ok <- salary_currency(sort, salary, currency) do
      {:ok,
       %{
         page: page,
         page_size: size,
         salary_min: salary,
         employment_type: type,
         work_mode: mode,
         scope: scope,
         sort: sort,
         status: status,
         q: search,
         industry: industry,
         location: location,
         currency: currency
       }}
    end
  end

  defp salary_currency(sort, salary, currency) do
    if (sort == "salary" or not is_nil(salary)) and not Regex.match?(~r/^[A-Za-z]{3}$/, currency) do
      {:error,
       {:invalid_params, %{"currency" => "choose a currency for salary filtering or sorting"}}}
    else
      :ok
    end
  end

  defp integer(params, key, default, min, max) do
    value = Map.get(params, key, default)

    parsed =
      cond do
        is_integer(value) -> {value, ""}
        is_binary(value) -> Integer.parse(value)
        true -> :error
      end

    case parsed do
      {n, ""} when n >= min and n <= max -> {:ok, n}
      _ when is_nil(value) and is_nil(default) -> {:ok, nil}
      _ -> {:error, {:invalid_params, %{key => "must be an integer between #{min} and #{max}"}}}
    end
  end

  defp choice(params, key, choices, default) do
    value = Map.get(params, key, default)

    if value in choices,
      do: {:ok, value},
      else: {:error, {:invalid_params, %{key => "invalid option"}}}
  end

  defp text(params, key) do
    case Map.get(params, key, "") do
      value when is_binary(value) and byte_size(value) <= 240 -> {:ok, String.trim(value)}
      _ -> {:error, {:invalid_params, %{key => "must be text up to 240 bytes"}}}
    end
  end

  defp apply_filters(query, f) do
    search = String.downcase(f.q)
    location = String.downcase(f.location)
    industry = String.downcase(f.industry)

    query =
      if search == "",
        do: query,
        else:
          Ash.Query.filter(
            query,
            contains(string_downcase(title), ^search) or
              contains(string_downcase(description), ^search) or
              contains(string_downcase(organization.name), ^search)
          )

    query =
      if location == "",
        do: query,
        else: Ash.Query.filter(query, contains(string_downcase(location), ^location))

    query =
      if industry == "",
        do: query,
        else: Ash.Query.filter(query, contains(string_downcase(industry), ^industry))

    query =
      if f.employment_type == "",
        do: query,
        else: Ash.Query.filter(query, employment_type == ^f.employment_type)

    query =
      if f.work_mode == "", do: query, else: Ash.Query.filter(query, work_mode == ^f.work_mode)

    query =
      if f.scope == "manage" and f.status != "",
        do: Ash.Query.filter(query, status == ^f.status),
        else: query

    query =
      if is_nil(f.salary_min),
        do: query,
        else: Ash.Query.filter(query, salary_max >= ^f.salary_min)

    currency = String.upcase(f.currency)
    if currency == "", do: query, else: Ash.Query.filter(query, currency == ^currency)
  end

  defp sort("salary"), do: [salary_max: :desc_nils_last, posted_at: :desc_nils_last, id: :asc]
  defp sort(_), do: [posted_at: :desc_nils_last, created_at: :desc, id: :asc]
end
