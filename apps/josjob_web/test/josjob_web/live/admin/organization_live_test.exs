defmodule JosjobWeb.Admin.OrganizationLiveTest do
  @moduledoc """
  Menu Organizations versi LiveView. Per-org: `organizations:read` melihat org
  aktifnya saja; `organizations:manage` boleh edit org sendiri; create/delete
  tenant = superuser saja.
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Industry, Membership, Organization}
  alias Josjob.Rbac.{MembershipRole, Permission, Role, RolePermission}

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

  defp staff_with_perms(org, perm_keys) do
    user = create_user("staff@gmail.com", "Staf Uji")

    role =
      Role
      |> Ash.Changeset.for_create(:create, %{key: "staff", name: "Staff", organization_id: org.id})
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

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

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

    {:ok, conn: login(conn, superuser), superuser: superuser, org: org, org_b: org_b}
  end

  test "tanpa organizations:read di-redirect", %{org: org} do
    conn = staff_with_perms(org, ["dashboard:view"])

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/organizations")
  end

  test "organizations:read: hanya org aktif; tombol New tersembunyi; /new ditolak",
       %{org: org} do
    conn = staff_with_perms(org, ["organizations:read"])

    {:ok, view, html} = live(conn, ~p"/organizations")
    assert html =~ "Org Alfa"
    refute html =~ "Org Beta"
    refute has_element?(view, "a", "New organization")

    assert {:error, {:live_redirect, %{to: "/organizations", flash: %{"error" => msg}}}} =
             live(conn, ~p"/organizations/new")

    assert msg =~ "permission"
  end

  test "organizations:manage: boleh edit org sendiri", %{org: org} do
    conn = staff_with_perms(org, ["organizations:read", "organizations:manage"])

    {:ok, view, _} = live(conn, ~p"/organizations/#{org.id}/edit")
    assert has_element?(view, "#organization-modal")

    view
    |> element("#organization-modal form")
    |> render_submit(%{"organization" => %{"name" => "Org Alfa Baru", "industry_id" => ""}})

    assert_patch(view, ~p"/organizations")
    assert render(view) =~ "Org Alfa Baru"
  end

  test "modal: dropdown industry berbentuk tree (anak menjorok di bawah induk)",
       %{conn: conn} do
    manufaktur =
      Industry
      |> Ash.Changeset.for_create(:create, %{name: "Manufaktur"})
      |> Ash.create!(authorize?: false)

    otomotif =
      Industry
      |> Ash.Changeset.for_create(:create, %{name: "Otomotif", parent_id: manufaktur.id})
      |> Ash.create!(authorize?: false)

    Industry
    |> Ash.Changeset.for_create(:create, %{name: "Karoseri", parent_id: otomotif.id})
    |> Ash.create!(authorize?: false)

    # filter di list juga berbentuk tree
    {:ok, view, _} = live(conn, ~p"/organizations")

    [filter_select] =
      Regex.run(~r/<select[^>]*name="industry_id".*?<\/select>/s, render(view))

    assert filter_select =~ ~r/Manufaktur.*└ Otomotif.*└ Karoseri/s

    {:ok, view, _} = live(conn, ~p"/organizations/new")

    [select] =
      Regex.run(
        ~r/<select[^>]*name="organization\[industry_id\]".*?<\/select>/s,
        render(view)
      )

    # urutan depth-first: induk lalu anak; anak diberi penanda indentasi
    assert [_, opts] = Regex.run(~r/<\/option>(.*)<\/select>/s, select)
    assert opts =~ ~r/Manufaktur.*└ Otomotif.*└ Karoseri/s
    # anak level 2 menjorok lebih dalam daripada level 1
    assert [_, karoseri_label] = Regex.run(~r/>([^<]*└ Karoseri)</, select)
    assert String.length(karoseri_label) > String.length("└ Karoseri") + 2
  end

  test "superuser: search + filter industri + create + delete",
       %{conn: conn, superuser: su, org_b: org_b} do
    las =
      Industry
      |> Ash.Changeset.for_create(:create, %{name: "Las"})
      |> Ash.create!(authorize?: false)

    Organization
    |> Ash.Changeset.for_create(:create, %{name: "Org Las", user_id: su.id, industry_id: las.id})
    |> Ash.create!(authorize?: false)

    {:ok, view, html} = live(conn, ~p"/organizations")
    assert html =~ "Org Alfa"
    assert html =~ "Org Las"

    # filter industri live
    view
    |> element("#organization-filter")
    |> render_change(%{"q" => "", "industry_id" => las.id})

    assert_patch(view, ~p"/organizations?industry_id=#{las.id}")
    html = render(view)
    assert html =~ "Org Las"
    refute html =~ "Org Alfa"

    # create (modal)
    {:ok, view, _} = live(conn, ~p"/organizations/new")

    view
    |> element("#organization-modal form")
    |> render_submit(%{
      "organization" => %{"name" => "Org Gamma", "user_id" => su.id, "industry_id" => ""}
    })

    assert_patch(view, ~p"/organizations")
    assert render(view) =~ "Org Gamma"

    # delete (org tanpa membership)
    {:ok, view, _} = live(conn, ~p"/organizations")
    view |> element(~s{[phx-click="delete"][phx-value-id="#{org_b.id}"]}) |> render_click()
    refute has_element?(view, "#organizations td", "Org Beta")
  end
end
