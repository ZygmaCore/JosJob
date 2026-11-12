defmodule StellarWeb.Api.JobController do
  use StellarWeb, :controller
  alias StellarJob.Listings

  def index(conn, params) do
    case Listings.list(conn.assigns.current_user, params) do
      {:ok, page} ->
        json(conn, %{
          data: Enum.map(page.jobs, &job_json(&1, page.organizations)),
          meta: page.meta,
          organizations: page.organizations
        })

      error ->
        respond_error(conn, error)
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Listings.get(user, id) do
      {:ok, job} -> json(conn, %{data: job_json(job, Listings.organizations(user))})
      error -> respond_error(conn, error)
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    case Listings.create(user, params["organization_id"], params) do
      {:ok, job} ->
        conn |> put_status(:created) |> json(%{data: job_json(job, Listings.organizations(user))})

      error ->
        respond_error(conn, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case Listings.update(user, id, params) do
      {:ok, job} -> json(conn, %{data: job_json(job, Listings.organizations(user))})
      error -> respond_error(conn, error)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Listings.delete(conn.assigns.current_user, id) do
      :ok -> send_resp(conn, :no_content, "")
      error -> respond_error(conn, error)
    end
  end

  defp job_json(job, orgs) do
    org = Enum.find(orgs, &(&1.id == job.organization_id))

    %{
      id: job.id,
      title: job.title,
      description: job.description,
      organization_id: job.organization_id,
      company: job.organization.name,
      location: job.location,
      industry: job.industry,
      employment_type: job.employment_type,
      work_mode: job.work_mode,
      requirements: job.requirements,
      highlights: job.highlights,
      salary_min: job.salary_min,
      salary_max: job.salary_max,
      currency: job.currency,
      salary_period: "month",
      status: job.status,
      synthetic: job.synthetic,
      posted_at: job.posted_at,
      created_at: job.created_at,
      can_manage: not is_nil(org) and org.can_manage
    }
  end

  defp respond_error(conn, {:error, :not_found}),
    do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp respond_error(conn, {:error, :forbidden}),
    do: conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

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
