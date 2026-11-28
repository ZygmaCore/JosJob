defmodule JosjobWeb.Api.JobController do
  use JosjobWeb, :controller
  alias JosjobJob.Listings
  alias JosjobWeb.Api.JobJSON

  def index(conn, params) do
    case listing_page(conn.assigns.current_user, params) do
      {:ok, page} ->
        json(conn, %{
          data:
            Enum.map(page.jobs, fn job ->
              JobJSON.listing(job, page.organizations)
              |> Map.put(:relevance, Map.get(Map.get(page, :relevance, %{}), job.id))
            end),
          meta: page.meta,
          organizations: page.organizations
        })

      error ->
        respond_error(conn, error)
    end
  end

  defp listing_page(nil, %{"sort" => "relevance"}), do: {:error, :unauthorized}

  defp listing_page(user, %{"sort" => "relevance"} = params) do
    case JosjobRag.CandidateProfile.cv(user, params["cv_id"]) do
      {:ok, cv} ->
        JosjobRag.CategoryRanking.list(user, cv, params)

      {:error, :not_found} when not is_map_key(params, "cv_id") ->
        with {:ok, page} <- Listings.list(user, Map.put(params, "sort", "newest")) do
          {:ok, put_in(page, [:meta, :relevance_status], "cv_required")}
        end

      error ->
        error
    end
  end

  defp listing_page(user, params), do: Listings.list(user, params)

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Listings.get(user, id) do
      {:ok, job} ->
        data =
          JobJSON.listing(job, Listings.organizations(user))
          |> Map.put(:my_application, JosjobJob.Applications.own_for(user, job.id))
          |> Map.put(:relevance, skill_fit(user, job))

        json(conn, %{data: data})

      error ->
        respond_error(conn, error)
    end
  end

  defp skill_fit(nil, _job), do: nil

  defp skill_fit(user, job) do
    profile = JosjobJob.CurriculumVitae.get_for(user)

    skills =
      case JosjobRag.CandidateProfile.cv(user) do
        {:ok, cv} -> cv["skills"] || []
        _ -> profile.skills
      end

    if skills == [] or job.requirements == [] do
      nil
    else
      {matched, missing} = JosjobRag.Text.split_skills(job.requirements, skills)

      %{
        relevance_label:
          "#{length(matched)} of #{length(matched) + length(missing)} required skills found",
        matched_skills: matched,
        missing_skills: missing
      }
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    case Listings.create(user, params["organization_id"], params) do
      {:ok, job} ->
        conn
        |> put_status(:created)
        |> json(%{data: JobJSON.listing(job, Listings.organizations(user))})

      error ->
        respond_error(conn, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case Listings.update(user, id, params) do
      {:ok, job} ->
        json(conn, %{data: JobJSON.listing(job, Listings.organizations(user))})

      error ->
        respond_error(conn, error)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Listings.delete(conn.assigns.current_user, id) do
      :ok ->
        _ = JosjobRag.VectorStore.delete(:job, id)
        send_resp(conn, :no_content, "")

      error ->
        respond_error(conn, error)
    end
  end

  defp respond_error(conn, {:error, :not_migrated}),
    do: conn |> put_status(:service_unavailable) |> json(%{error: "cv_storage_unavailable"})

  defp respond_error(conn, {:error, :not_found}),
    do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp respond_error(conn, {:error, :unauthorized}),
    do: conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

  defp respond_error(conn, {:error, :forbidden}),
    do: conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

  defp respond_error(conn, {:error, :applications_exist}),
    do: conn |> put_status(:conflict) |> json(%{error: "applications_exist"})

  defp respond_error(conn, {:error, {:invalid_params, fields}}),
    do: conn |> put_status(:bad_request) |> json(%{error: "invalid_params", fields: fields})

  defp respond_error(conn, {:error, %Ash.Error.Invalid{} = error}) do
    fields =
      Enum.reduce(error.errors, %{}, fn detail, acc ->
        key = Map.get(detail, :field) || :base
        Map.update(acc, key, [Exception.message(detail)], &[Exception.message(detail) | &1])
      end)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_failed", fields: fields})
  end
end
