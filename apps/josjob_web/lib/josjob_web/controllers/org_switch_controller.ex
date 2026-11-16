defmodule JosjobWeb.OrgSwitchController do
  @moduledoc """
  Ganti organisasi aktif (org switcher). Menyimpan `active_organization_id` di
  session lalu redirect ke dashboard. Hanya boleh pindah ke org tempat user
  benar-benar member aktif (validasi server-side).
  """
  use JosjobWeb, :controller

  def update(conn, %{"organization_id" => org_id}) do
    allowed =
      conn.assigns[:current_user]
      |> Josjob.Authz.member_orgs()
      |> Enum.map(& &1.id)

    conn =
      if org_id in allowed,
        do: put_session(conn, "active_organization_id", org_id),
        else: put_flash(conn, :error, "Invalid organization.")

    redirect(conn, to: ~p"/dashboard")
  end
end
