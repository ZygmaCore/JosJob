defmodule JosjobWeb.Api.JobController do
  use JosjobWeb, :controller
  alias JosjobJob.Listings
  alias JosjobWeb.Api.JobJSON

  def index(conn, params) do
    case Listings.list(conn.assigns.current_user, params) do
      {:ok, page} ->
        json(conn, %{
          data: Enum.map(page.jobs, &JobJSON.listing(&1, page.organizations)),
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
      {:ok, job} -> json(conn, %{data: JobJSON.listing(job, Listings.organizations(user))})
      error -> respond_error(conn, error)
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
      {:ok, job} -> json(conn, %{data: JobJSON.listing(job, Listings.organizations(user))})
      error -> respond_error(conn, error)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Listings.delete(conn.assigns.current_user, id) do
      :ok -> send_resp(conn, :no_content, "")
      error -> respond_error(conn, error)
    end
  end

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
