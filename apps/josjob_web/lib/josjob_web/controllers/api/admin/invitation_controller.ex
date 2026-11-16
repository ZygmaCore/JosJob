defmodule JosjobWeb.Api.Admin.InvitationController do
  @moduledoc """
  API undangan teacher untuk **superuser** (Bearer + `RequireSuperuserApi`).

    * `GET  /api/admin/teacher-invitations`            → daftar undangan
    * `POST /api/admin/teacher-invitations`            → undang {email, organization_id}
    * `POST /api/admin/teacher-invitations/:id/resend` → kirim ulang

  Orkestrasi di `Josjob.Invitations.Service`; controller hanya map JSON + error.
  """
  use JosjobWeb, :controller

  alias Josjob.Invitations.Service

  # GET /api/admin/teacher-invitations
  def index(conn, _params) do
    json(conn, %{data: Enum.map(Service.list(), &invitation_json/1)})
  end

  # POST /api/admin/teacher-invitations
  def create(conn, params) do
    attrs = %{
      email: params["email"],
      organization_id: params["organization_id"],
      role_key: params["role_key"] || "teacher",
      invited_by_id: conn.assigns.current_user.id
    }

    case Service.invite(attrs) do
      {:ok, invitation} ->
        conn |> put_status(:created) |> json(%{data: invitation_json(invitation)})

      {:error, reason} ->
        error(conn, reason)
    end
  end

  # POST /api/admin/teacher-invitations/:id/resend
  def resend(conn, %{"id" => id}) do
    case Service.resend(id) do
      {:ok, invitation} -> json(conn, %{data: invitation_json(invitation)})
      {:error, reason} -> error(conn, reason)
    end
  end

  # --- JSON / errors ---

  defp invitation_json(inv) do
    %{
      id: inv.id,
      email: to_string(inv.email),
      organization_id: inv.organization_id,
      organization_name: org_name(inv),
      role_key: inv.role_key,
      status: to_string(inv.status),
      resend_count: inv.resend_count,
      expires_at: inv.expires_at,
      accepted_at: inv.accepted_at,
      last_sent_at: inv.last_sent_at,
      created_at: inv.created_at
    }
  end

  defp org_name(%{organization: %{name: name}}), do: name
  defp org_name(_), do: nil

  defp error(conn, :not_found),
    do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp error(conn, :email_failed),
    do: conn |> put_status(:bad_gateway) |> json(%{error: "email_failed"})

  defp error(conn, reason),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
end
