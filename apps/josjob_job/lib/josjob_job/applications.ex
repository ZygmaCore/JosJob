defmodule JosjobJob.Applications do
  @moduledoc "Private applications, organization-scoped hiring and serialized stage changes."
  import Ecto.Query
  alias Josjob.{Authz, Repo}
  alias JosjobJob.{Application, ApplicationEvent, CurriculumVitae, Listings}

  @transitions %{
    "applied" => ~w(reviewing rejected),
    "reviewing" => ~w(interview rejected),
    "interview" => ~w(offer rejected),
    "offer" => ~w(hired rejected)
  }

  def active?(application), do: Map.has_key?(@transitions, application.status)

  def manager?(user, application),
    do:
      user.id != application.candidate_id and
        Authz.can?(user, application.organization_id, "jobs:manage")

  def allowed?(user, application),
    do: user.id == application.candidate_id or manager?(user, application)

  def own_for(nil, _job_id), do: nil

  def own_for(user, job_id) do
    Repo.one(
      from(a in Application,
        where: a.job_id == ^job_id and a.candidate_id == ^user.id,
        select: %{id: a.id, status: a.status}
      )
    )
  end

  def get(user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Application{} = application <- Repo.one(from(a in joined(), where: a.id == ^id)),
         true <- allowed?(user, application) do
      {:ok, application}
    else
      _ -> {:error, :not_found}
    end
  end

  def list(user, params) do
    scope = Map.get(params, "scope", "mine")
    status = Map.get(params, "status", "")
    organizations = Listings.organizations(user) |> Enum.filter(& &1.can_manage)
    org_ids = Enum.map(organizations, & &1.id)

    with true <- scope in ~w(mine hiring),
         true <-
           status in [
             "",
             "applied",
             "reviewing",
             "interview",
             "offer",
             "hired",
             "rejected",
             "withdrawn"
           ],
         {:ok, page} <- page_number(Map.get(params, "page", "1")),
         {:ok, job_id} <- optional_job_id(params["job_id"]),
         true <- scope == "mine" or org_ids != [] do
      query =
        if scope == "mine",
          do: from(a in joined(), where: a.candidate_id == ^user.id),
          else:
            from([a, j, o, u] in joined(),
              where: type(o.id, Ecto.UUID) in ^org_ids and a.candidate_id != ^user.id
            )

      query = if job_id, do: from(a in query, where: a.job_id == ^job_id), else: query

      counts =
        Repo.all(from(a in subquery(query), group_by: a.status, select: {a.status, count(a.id)}))
        |> Map.new()

      filtered = if status == "", do: query, else: from(a in query, where: a.status == ^status)
      total = Repo.aggregate(filtered, :count)

      applications =
        Repo.all(
          from(a in filtered,
            order_by: [desc: a.inserted_at, asc: a.id],
            limit: 25,
            offset: ^((page - 1) * 25)
          )
        )

      {:ok,
       %{
         applications: applications,
         counts: counts,
         organizations: organizations,
         meta: %{page: page, total: total, total_pages: ceil(total / 25)}
       }}
    else
      _ -> {:error, :invalid_params}
    end
  end

  def submit(user, job_id, params) do
    with true <- params["consent"] == true,
         {:ok, job_id} <- Ecto.UUID.cast(job_id) do
      Repo.transaction(fn ->
        Repo.query!("SELECT id FROM jobs WHERE id = $1::uuid FOR UPDATE", [
          Ecto.UUID.dump!(job_id)
        ])

        job =
          case Listings.get(user, job_id) do
            {:ok, job} -> job
            _ -> Repo.rollback(:not_found)
          end

        if job.status != "active", do: Repo.rollback(:job_closed)

        if job.created_by == user.id or Authz.can?(user, job.organization_id, "jobs:manage"),
          do: Repo.rollback(:self_application)

        snapshot =
          CurriculumVitae.get_for(user)
          |> Map.drop([:pdf_documents])
          |> Jason.encode!()
          |> Jason.decode!()

        application = %Application{
          job_id: job.id,
          candidate_id: user.id,
          profile_snapshot: snapshot
        }

        changeset = Application.submission_changeset(application, params)

        changeset =
          if is_nil(Ecto.Changeset.get_field(changeset, :cover_letter)),
            do: Ecto.Changeset.add_error(changeset, :cover_letter, "must be text"),
            else: changeset

        case Repo.insert(changeset) do
          {:ok, record} ->
            record_event(record, user, "", nil)
            record

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
      |> load_result(user)
    else
      false -> {:error, :consent_required}
      _ -> {:error, :not_found}
    end
  end

  def advance(user, id, params) do
    with {:ok, application} <- get(user, id) do
      Repo.transaction(fn ->
        locked = Repo.one!(from(a in Application, where: a.id == ^id, lock: "FOR UPDATE"))
        application = %{application | status: locked.status, interview_at: locked.interview_at}
        target = params["status"]
        if params["expected_status"] != application.status, do: Repo.rollback(:stale_application)
        if target not in next_statuses(user, application), do: Repo.rollback(:invalid_transition)
        note = params["note"] || ""
        if not is_binary(note) or String.length(note) > 2000, do: Repo.rollback(:invalid_note)
        scheduled = interview_date(target, params["interview_at"])
        changes = %{status: target}

        changes =
          if target == "interview", do: Map.put(changes, :interview_at, scheduled), else: changes

        updated = locked |> Ecto.Changeset.change(changes) |> Repo.update!()
        record_event(updated, user, String.trim(note), scheduled)
        updated
      end)
      |> load_result(user)
    end
  end

  def next_statuses(user, application) do
    cond do
      not active?(application) -> []
      user.id == application.candidate_id -> ["withdrawn"]
      manager?(user, application) -> Map.get(@transitions, application.status, [])
      true -> []
    end
  end

  def summary(application, user) do
    %{
      id: application.id,
      job_id: application.job_id,
      job_title: application.job_title,
      company: application.company,
      candidate_name: application.candidate_name,
      status: application.status,
      applied_at: application.inserted_at,
      updated_at: application.updated_at,
      interview_at: application.interview_at,
      can_manage: manager?(user, application),
      next_statuses: next_statuses(user, application),
      can_chat: active?(application)
    }
  end

  def detail(application, user) do
    events =
      Repo.all(
        from(e in ApplicationEvent,
          where: e.application_id == ^application.id,
          order_by: [asc: e.inserted_at, asc: e.id]
        )
      )

    summary(application, user)
    |> Map.merge(%{
      cover_letter: application.cover_letter,
      profile: application.profile_snapshot,
      history:
        Enum.map(
          events,
          &%{
            id: &1.id,
            status: &1.status,
            note: &1.note,
            scheduled_at: &1.scheduled_at,
            created_at: &1.inserted_at
          }
        )
    })
  end

  defp joined do
    from(a in Application,
      join: j in "jobs",
      on: j.id == a.job_id,
      join: o in "organizations",
      on: o.id == j.organization_id,
      join: u in "users",
      on: u.id == a.candidate_id,
      select_merge: %{
        job_title: j.title,
        company: o.name,
        organization_id: type(o.id, Ecto.UUID),
        candidate_name: u.full_name
      }
    )
  end

  defp record_event(application, user, note, scheduled) do
    Repo.insert!(%ApplicationEvent{
      application_id: application.id,
      actor_id: user.id,
      status: application.status,
      note: note,
      scheduled_at: scheduled
    })
  end

  defp interview_date("interview", date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, datetime, _} ->
        # Normalize browser ISO8601 seconds/milliseconds for Ecto's usec dumper.
        datetime = datetime |> DateTime.to_unix(:microsecond) |> DateTime.from_unix!(:microsecond)

        if DateTime.compare(datetime, DateTime.utc_now()) == :gt,
          do: datetime,
          else: Repo.rollback(:invalid_interview_date)

      _ ->
        Repo.rollback(:invalid_interview_date)
    end
  end

  defp interview_date("interview", nil), do: nil
  defp interview_date("interview", _), do: Repo.rollback(:invalid_interview_date)
  defp interview_date(_, _), do: nil
  defp load_result({:ok, application}, user), do: get(user, application.id)
  defp load_result(error, _), do: error

  defp page_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n in 1..10_000 -> {:ok, n}
      _ -> :error
    end
  end

  defp page_number(_), do: :error
  defp optional_job_id(nil), do: {:ok, nil}
  defp optional_job_id(id), do: Ecto.UUID.cast(id)
end
