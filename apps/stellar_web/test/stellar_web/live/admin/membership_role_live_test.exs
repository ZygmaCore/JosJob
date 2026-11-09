defmodule StellarWeb.Admin.MembershipRoleLiveTest do
  @moduledoc """
  Menu Membership Roles versi LiveView. Fokus: scoping per-org dan ANTI-ESKALASI
  (non-superuser tak boleh menautkan role yang izinnya melebihi izin dirinya).
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_org(name, owner) do
    Organization
    |> Ash.Changeset.for_create(:create, %{name: name, user_id: owner.id})
    |> Ash.create!(authorize?: false)
  end

  defp create_membership(user, org) do
    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      organization_id: org.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_role(key, name, org_id, perm_keys) do
    role =
      Role
      |> Ash.Changeset.for_create(:create, %{key: key, name: name, organization_id: org_id})
      |> Ash.create!(authorize?: false)

    Enum.each(perm_keys, fn key ->
      permission = ensure_permission(key)

      RolePermission
      |> Ash.Changeset.for_create(:create, %{role_id: role.id, permission_id: permission.id})
      |> Ash.create!(authorize?: false)
    end)

    role
  end

  defp ensure_permission(key) do
    Permission
    |> Ash.Query.filter(key == ^key)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil ->
        Permission
        |> Ash.Changeset.for_create(:create, %{key: key})
        |> Ash.create!(authorize?: false)

      p ->
        p
    end
  end

  defp link_role(membership, role) do
    MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)
  end

  # Staf org dengan role ber-permission `perm_keys`.
  defp staff(org, perm_keys) do
    user = create_user("staff@gmail.com", "Staf Uji")
    role = create_role("staff", "Staff", org.id, perm_keys)
    membership = create_membership(user, org)
    link_role(membership, role)
    {login(Phoenix.ConnTest.build_conn(), user), membership}
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)
    org_b = create_org("Org Beta", superuser)

    {:ok, conn: login(conn, superuser), org: org, org_b: org_b}
  end

  test "index ter-scope org aktif untuk non-superuser", %{org: org, org_b: org_b} do
    {conn, _} = staff(org, ["members:read"])

    luar = create_user("luar@gmail.com", "Anggota Beta")
    m_luar = create_membership(luar, org_b)
    role_b = create_role("viewer", "Viewer Beta", org_b.id, [])
    link_role(m_luar, role_b)

    {:ok, _view, html} = live(conn, ~p"/membership-roles")

    # tautan milik org sendiri (role Staff) tampil; milik org lain tidak
    assert html =~ "staff@gmail.com"
    refute html =~ "luar@gmail.com"
  end

  test "anti-eskalasi: role ber-izin melebihi milik sendiri DITOLAK", %{org: org} do
    {conn, _m} = staff(org, ["members:read", "members:manage"])

    target = create_user("target@gmail.com", "Anggota Baru")
    target_m = create_membership(target, org)
    kuat = create_role("kuat", "Role Kuat", org.id, ["classes:manage"])

    {:ok, view, _} = live(conn, ~p"/membership-roles/new")

    # dropdown role tidak menawarkan role yang melebihi izin
    [role_select] =
      Regex.run(~r/<select[^>]*name="membership_role\[role_id\]".*?<\/select>/s, render(view))

    refute role_select =~ kuat.id

    # submit paksa tetap ditolak + tidak tersimpan
    view
    |> element("#membership-role-modal form")
    |> render_submit(%{
      "membership_role" => %{"membership_id" => target_m.id, "role_id" => kuat.id}
    })

    assert render(view) =~ "cannot be linked"

    assert MembershipRole
           |> Ash.Query.filter(membership_id == ^target_m.id)
           |> Ash.read!(authorize?: false) == []
  end

  test "non-superuser boleh menautkan role yang izinnya subset miliknya", %{org: org} do
    {conn, _m} = staff(org, ["members:read", "members:manage", "dashboard:view"])

    target = create_user("target@gmail.com", "Anggota Baru")
    target_m = create_membership(target, org)
    ringan = create_role("viewer", "Viewer", org.id, ["dashboard:view"])

    {:ok, view, _} = live(conn, ~p"/membership-roles/new")

    view
    |> element("#membership-role-modal form")
    |> render_submit(%{
      "membership_role" => %{"membership_id" => target_m.id, "role_id" => ringan.id}
    })

    assert_patch(view, ~p"/membership-roles")
    assert render(view) =~ "linked"

    assert [mr] =
             MembershipRole
             |> Ash.Query.filter(membership_id == ^target_m.id)
             |> Ash.read!(authorize?: false)

    assert mr.role_id == ringan.id
  end

  test "superuser: create + delete", %{conn: conn, org: org} do
    target = create_user("target@gmail.com", "Anggota Baru")
    target_m = create_membership(target, org)
    role = create_role("viewer", "Viewer", org.id, [])

    {:ok, view, _} = live(conn, ~p"/membership-roles/new")

    view
    |> element("#membership-role-modal form")
    |> render_submit(%{
      "membership_role" => %{"membership_id" => target_m.id, "role_id" => role.id}
    })

    assert_patch(view, ~p"/membership-roles")
    assert render(view) =~ "target@gmail.com"

    [mr] =
      MembershipRole
      |> Ash.Query.filter(membership_id == ^target_m.id)
      |> Ash.read!(authorize?: false)

    {:ok, view, _} = live(conn, ~p"/membership-roles")
    view |> element(~s{[phx-click="delete"][phx-value-id="#{mr.id}"]}) |> render_click()

    refute has_element?(view, "#membership-roles td", "target@gmail.com")
    assert render(view) =~ "deleted"
  end
end
