defmodule JosjobWeb.Api.CurriculumVitaeController do
  use JosjobWeb, :controller
  alias JosjobJob.CurriculumVitae

  def show(conn, _params), do: json(conn, %{data: data(conn.assigns.current_user)})

  def update(conn, params) do
    case CurriculumVitae.save_for(conn.assigns.current_user, params) do
      {:ok, _} ->
        json(conn, %{data: data(conn.assigns.current_user)})

      {:error, :invalid_resume_document} ->
        conn |> put_status(422) |> json(%{error: "invalid_resume_document"})

      {:error, _} ->
        invalid(conn)
    end
  rescue
    _ in Ash.Error.Invalid -> invalid(conn)
  end

  defp invalid(conn), do: conn |> put_status(422) |> json(%{error: "invalid_cv_profile"})

  defp data(user) do
    user
    |> CurriculumVitae.get_for()
    |> Map.put(:certificates, JosjobLrn.Certificates.list_for(user))
  end
end
