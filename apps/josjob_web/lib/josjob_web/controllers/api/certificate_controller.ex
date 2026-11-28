defmodule JosjobWeb.Api.CertificateController do
  use JosjobWeb, :controller
  alias JosjobLrn.Certificates

  def index(conn, _), do: json(conn, %{data: Certificates.list_for(conn.assigns.current_user)})

  def create(conn, params) do
    case Certificates.add_certificate(conn.assigns.current_user, params) do
      {:ok, c} -> conn |> put_status(:created) |> json(%{data: Certificates.to_json(c)})
      error -> respond(conn, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Certificates.update_certificate(conn.assigns.current_user, id, params) do
      {:ok, c} -> json(conn, %{data: Certificates.to_json(c)})
      error -> respond(conn, error)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Certificates.delete_certificate(conn.assigns.current_user, id) do
      :ok -> json(conn, %{ok: true})
      error -> respond(conn, error)
    end
  end

  defp respond(conn, {:error, :not_found}),
    do: conn |> put_status(404) |> json(%{error: "not_found"})

  defp respond(conn, {:error, :certificate_locked}),
    do: conn |> put_status(409) |> json(%{error: "certificate_locked"})

  defp respond(conn, {:error, _}),
    do: conn |> put_status(422) |> json(%{error: "invalid_certificate"})
end
