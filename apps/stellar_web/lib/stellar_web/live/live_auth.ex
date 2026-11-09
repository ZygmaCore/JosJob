defmodule StellarWeb.LiveAuth do
  @moduledoc """
  Hook `on_mount` untuk LiveView admin — padanan plug pipeline (yang hanya
  menjaga mount HTTP pertama; hook juga menjaga reconnect websocket).

  - `:require_admin` — superuser only (padanan `Plugs.RequireAdmin`, wording sama).
  - `:assign_org` — padanan `Plugs.AssignActiveOrg`: set assigns
    `:active_organization_id`, `:permissions` (`:all`/MapSet), `:member_orgs`
    dari session + `Stellar.Authz`.
  - `{:require, perms}` — padanan `Plugs.RequirePermission` (wording sama);
    butuh `:assign_org` dijalankan lebih dulu di daftar on_mount.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias Stellar.Authz

  def on_mount(:require_admin, _params, _session, socket) do
    if Authz.superuser?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in as an administrator to access this page.")
       |> redirect(to: "/")}
    end
  end

  def on_mount(:assign_org, _params, session, socket) do
    {:cont, assign_org(socket, socket.assigns[:current_user], session)}
  end

  # Padanan Plugs.RequireMember: superuser ATAU punya membership aktif.
  def on_mount(:require_member, _params, _session, socket) do
    if Authz.member?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in to access this page.")
       |> redirect(to: "/")}
    end
  end

  def on_mount({:require, perms}, _params, _session, socket) do
    if StellarWeb.Perms.can?(socket.assigns[:permissions], perms) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You don't have permission to access that page.")
       |> redirect(to: "/")}
    end
  end

  # Cabang identik dengan Plugs.AssignActiveOrg (session menggantikan get_session).
  defp assign_org(socket, nil, _session) do
    socket
    |> assign(:active_organization_id, nil)
    |> assign(:permissions, MapSet.new())
    |> assign(:member_orgs, [])
  end

  defp assign_org(socket, %{is_superuser: true}, _session) do
    socket
    |> assign(:active_organization_id, nil)
    |> assign(:permissions, :all)
    |> assign(:member_orgs, [])
  end

  defp assign_org(socket, user, session) do
    org_id = Authz.active_org_id(session["active_organization_id"], user)
    perms = if org_id, do: Authz.permissions_for(user, org_id), else: MapSet.new()

    socket
    |> assign(:active_organization_id, org_id)
    |> assign(:permissions, perms)
    |> assign(:member_orgs, Authz.member_orgs(user))
  end
end
