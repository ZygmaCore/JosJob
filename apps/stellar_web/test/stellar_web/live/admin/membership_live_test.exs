defmodule StellarWeb.Admin.MembershipLiveTest do
  @moduledoc """
  Menu Memberships versi LiveView. Fokus per-org: scoping data org aktif,
  members:read = lihat saja, members:manage = kelola, create non-superuser
  dipaksa ke org aktif.
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

  defp create_membership(user, org, status \\ :active) do
    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      organization_id: org.id,
      status: status
    })
    |> Ash.create!(authorize?: false)
  end

  # Non-superuser ber-permission `perm_keys` di `org` (role "staff" + membership aktif).
  defp staff_with_perms(conn, org, perm_keys) do
    user = create_user("staff@gmail.com", "Staf Uji")

    role =
      Role
      |> Ash.Changeset.for_create(:create, %{
        key: "staff",
        name: "Staff",
        organization_id: org.id
      })
      |> Ash.create!(authorize?: false)

    Enum.each(perm_keys, fn key ->
      permission =
        Permission
        |> Ash.Changeset.for_create(:create, %{key: key})
        |> Ash.create!(authorize?: false)

      RolePermission
      |> Ash.Changeset.for_create(:create, %{role_id: role.id, permission_id: permission.id})
      |> Ash.create!(authorize?: false)
    end)

    membership = create_membership(user, org)

    MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)

    login(Phoenix.ConnTest.build_conn(), user)
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

  test "tanpa members:* di-redirect", %{conn: _, org: org} do
    conn = staff_with_perms(Phoenix.ConnTest.build_conn(), org, ["dashboard:view"])

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/memberships")
  end

  test "members:read: list ter-scope org aktif, tombol manage disembunyikan, /new ditolak",
       %{org: org, org_b: org_b} do
    anggota_a = create_user("anggotaa@gmail.com", "Anggota Alfa")
    create_membership(anggota_a, org)
    anggota_b = create_user("anggotab@gmail.com", "Anggota Beta")
    create_membership(anggota_b, org_b)

    conn = staff_with_perms(Phoenix.ConnTest.build_conn(), org, ["members:read"])

    {:ok, view, html} = live(conn, ~p"/memberships")
    assert html =~ "anggotaa@gmail.com"
    refute html =~ "anggotab@gmail.com"
    refute has_element?(view, "a", "New membership")

    # akses langsung modal new -> dilempar balik ke index + flash forbid
    assert {:error, {:live_redirect, %{to: "/memberships", flash: %{"error" => msg}}}} =
             live(conn, ~p"/memberships/new")

    assert msg =~ "permission"
  end

  test "members:manage non-superuser: create dipaksa ke org aktif", %{org: org, org_b: org_b} do
    target = create_user("target@gmail.com", "Calon Anggota")
    conn = staff_with_perms(Phoenix.ConnTest.build_conn(), org, ["members:manage"])

    {:ok, view, _} = live(conn, ~p"/memberships/new")
    assert has_element?(view, "#membership-modal")

    # coba paksa org lain lewat params -> tetap tersimpan di org aktif
    view
    |> element("#membership-modal form")
    |> render_submit(%{
      "membership" => %{
        "user_id" => target.id,
        "organization_id" => org_b.id,
        "status" => "active"
      }
    })

    assert_patch(view, ~p"/memberships")

    created =
      Membership
      |> Ash.Query.filter(user_id == ^target.id)
      |> Ash.read_one!(authorize?: false)

    assert created.organization_id == org.id
  end

  test "superuser: search live + edit status + delete", %{conn: conn, org: org} do
    anggota = create_user("anggota@gmail.com", "Anggota Uji")
    m = create_membership(anggota, org, :invited)

    {:ok, view, html} = live(conn, ~p"/memberships")
    assert html =~ "anggota@gmail.com"

    # search live (in-memory label filter) + URL
    view |> element("#membership-filter") |> render_change(%{"q" => "tidakada"})
    assert_patch(view, ~p"/memberships?q=tidakada")
    refute has_element?(view, "#memberships td", "anggota@gmail.com")

    # edit status -> active
    {:ok, view, _} = live(conn, ~p"/memberships/#{m.id}/edit")

    view
    |> element("#membership-modal form")
    |> render_submit(%{
      "membership" => %{
        "user_id" => anggota.id,
        "organization_id" => org.id,
        "status" => "active"
      }
    })

    assert_patch(view, ~p"/memberships")
    assert Ash.get!(Membership, m.id, authorize?: false).status == :active

    # delete
    {:ok, view, _} = live(conn, ~p"/memberships")
    view |> element(~s{[phx-click="delete"][phx-value-id="#{m.id}"]}) |> render_click()
    refute has_element?(view, "#memberships td", "anggota@gmail.com")
  end
end
