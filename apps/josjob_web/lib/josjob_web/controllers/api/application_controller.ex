defmodule JosjobWeb.Api.ApplicationController do
  use JosjobWeb, :controller
  alias JosjobJob.Applications
  alias JosjobWeb.Api.WorkflowError

  def suggestions(conn, %{"job_id" => id}) do
    case JosjobRag.ApplicationSuggestions.get(conn.assigns.current_user, id) do
      {:ok, suggestions} ->
        json(conn, %{data: suggestions})

      {:error, reason} = error when reason in [:not_found, :job_closed] ->
        WorkflowError.respond(conn, error)

      {:error, _reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "suggestions_unavailable"})
    end
  end

  def index(conn, params) do
    user = conn.assigns.current_user

    case Applications.list(user, params) do
      {:ok, page} ->
        json(conn, %{
          data: Enum.map(page.applications, &Applications.summary(&1, user)),
          counts: page.counts,
          organizations: page.organizations,
          meta: page.meta
        })

      error ->
        WorkflowError.respond(conn, error)
    end
  end

  def show(conn, %{"id" => id}) do
    case Applications.get(conn.assigns.current_user, id) do
      {:ok, application} ->
        json(conn, %{data: Applications.detail(application, conn.assigns.current_user)})

      error ->
        WorkflowError.respond(conn, error)
    end
  end

  def create(conn, %{"job_id" => id} = params) do
    case Applications.submit(conn.assigns.current_user, id, params) do
      {:ok, application} ->
        conn
        |> put_status(201)
        |> json(%{data: Applications.detail(application, conn.assigns.current_user)})

      error ->
        WorkflowError.respond(conn, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Applications.advance(conn.assigns.current_user, id, params) do
      {:ok, application} ->
        json(conn, %{data: Applications.detail(application, conn.assigns.current_user)})

      error ->
        WorkflowError.respond(conn, error)
    end
  end
end
