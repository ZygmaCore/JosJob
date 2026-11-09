defmodule StellarWeb.Admin.RoleLiveTest do
  @moduledoc """
  Menu Roles versi LiveView (pola pilot Skills): list + modal form + delete.
  Termasuk port perilaku lama dari RoleControllerTest: `is_system` tidak tampil
  di UI mana pun; role baru default `is_system: false`; update tidak mereset
  `is_system` role sistem.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Rbac.{Permission, Role, RolePermission}

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_role(key, name, is_system \\ false) do
    Role
    |> Ash.Changeset.for_create(:create, %{key: key, name: name, is_system: is_system})
    |> Ash.create!(authorize?: false)
  end

  defp create_permission(key) do
    Permission
    |> Ash.Changeset.for_create(:create, %{key: key})
    |> Ash.create!(authorize?: false)
  end

  defp role_permission_ids(role_id) do
    RolePermission
    |> Ash.Query.filter(role_id == ^role_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.permission_id)
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
    {:ok, conn: login(conn, superuser)}
  end

  test "non-superuser di-redirect", %{conn: _} do
    biasa = create_user("biasa@gmail.com", "User Biasa")
    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/roles")
  end

  test "list: tanpa kolom/badge System; role tampil", %{conn: conn} do
    create_role("teacher", "Teacher", true)

    {:ok, _view, html} = live(conn, ~p"/roles")

    assert html =~ "Teacher"
    refute html =~ "badge-neutral"
  end

  test "modal new: tanpa checkbox System role; create men-sync permissions; is_system false",
       %{conn: conn} do
    perm = create_permission("classes:read")

    {:ok, view, _} = live(conn, ~p"/roles/new")
    assert has_element?(view, "#role-modal")
    refute render(view) =~ "System role"

    view
    |> element("#role-modal form")
    |> render_submit(%{
      "role" => %{
        "key" => "auditor",
        "name" => "Auditor",
        "organization_id" => "",
        "permission_ids" => [perm.id]
      }
    })

    assert_patch(view, ~p"/roles")
    assert render(view) =~ "Auditor"

    role = Role |> Ash.Query.filter(key == "auditor") |> Ash.read_one!(authorize?: false)
    assert role.is_system == false
    assert role_permission_ids(role.id) == [perm.id]
  end

  test "modal edit: tanpa checkbox System role; update tidak mereset is_system; sync permissions",
       %{conn: conn} do
    perm = create_permission("classes:read")
    role = create_role("teacher", "Teacher", true)

    RolePermission
    |> Ash.Changeset.for_create(:create, %{role_id: role.id, permission_id: perm.id})
    |> Ash.create!(authorize?: false)

    {:ok, view, html} = live(conn, ~p"/roles/#{role.id}/edit")
    refute html =~ "System role"

    # uncheck memicu phx-change (validate) dulu — persis alur browser; setelah
    # itu DOM checkbox tak tercentang sehingga submit tidak membawanya.
    render_change(view, "validate", %{
      "role" => %{"key" => "teacher", "name" => "Pengajar", "organization_id" => ""}
    })

    view
    |> element("#role-modal form")
    |> render_submit(%{
      "role" => %{"key" => "teacher", "name" => "Pengajar", "organization_id" => ""}
    })

    assert_patch(view, ~p"/roles")
    assert render(view) =~ "Pengajar"

    reloaded = Ash.get!(Role, role.id, authorize?: false)
    assert reloaded.is_system == true
    assert role_permission_ids(role.id) == []
  end

  test "delete menghapus role dari list", %{conn: conn} do
    role = create_role("auditor", "Auditor Hapus")

    {:ok, view, html} = live(conn, ~p"/roles")
    assert html =~ "Auditor Hapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{role.id}"]}) |> render_click()

    refute has_element?(view, "#roles td", "Auditor Hapus")
    assert render(view) =~ "deleted"
  end
end
