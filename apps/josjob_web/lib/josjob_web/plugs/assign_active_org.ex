defmodule JosjobWeb.Plugs.AssignActiveOrg do
  @moduledoc """
  Set `conn.assigns.active_organization_id` + `conn.assigns.permissions` untuk
  user login. `permissions` = `:all` (superuser) atau `MapSet` key izin efektif
  pada org aktif. Dipasang di pipeline `:browser` setelah `load_josjob_user`.
  """
  import Plug.Conn
  alias Josjob.Authz

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> assign(:active_organization_id, nil)
        |> assign(:permissions, MapSet.new())
        |> assign(:member_orgs, [])

      %{is_superuser: true} ->
        conn
        |> assign(:active_organization_id, nil)
        |> assign(:permissions, :all)
        |> assign(:member_orgs, [])

      user ->
        org_id = Authz.active_org_id(get_session(conn, "active_organization_id"), user)
        perms = if org_id, do: Authz.permissions_for(user, org_id), else: MapSet.new()

        conn
        |> assign(:active_organization_id, org_id)
        |> assign(:permissions, perms)
        |> assign(:member_orgs, Authz.member_orgs(user))
    end
  end
end
