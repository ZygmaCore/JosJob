defmodule StellarWeb.AdminNavTest do
  @moduledoc """
  Visibilitas menu sidebar "Classes". Gate-nya (`class_perms/0` di Layouts) adalah
  OR atas `classes:*` DAN `enrollments:*` — melepas `classes:*` saja belum cukup
  untuk menyembunyikan menu.
  """
  use StellarWeb.ConnCase, async: false

  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}

  # User non-superuser, member aktif di sebuah org, dengan role ber-permission `perm_keys`.
  defp member_with_perms(conn, perm_keys) do
    owner = create_user("owner@gmail.com", "Owner")
    user = create_user("teacher@gmail.com", "Guru Uji")

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{name: "Atveti Uji", user_id: owner.id})
      |> Ash.create!(authorize?: false)

    role =
      Role
      |> Ash.Changeset.for_create(:create, %{
        key: "teacher",
        name: "Teacher",
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

    login(conn, user)
  end

  defp create_user(email, full_name) do
    User
    |> Ash.Changeset.for_create(:create, %{email: email, full_name: full_name})
    |> Ash.create!(authorize?: false)
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  test "melepas classes:* tapi menyisakan enrollments:* — menu Classes tetap tampil",
       %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view", "enrollments:manage"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    assert body =~ ~s(href="/classes")
  end

  test "tanpa classes:* maupun enrollments:* — menu Classes hilang", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    refute body =~ ~s(href="/classes")
  end

  test "tanpa classes:* maupun enrollments:* — akses /classes ditolak", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view"])

    assert conn |> get(~p"/classes") |> redirected_to() == "/"
  end

  test "dengan teachers:read — menu Teachers tampil", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view", "teachers:read"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    assert body =~ ~s(href="/teachers")
  end

  test "tanpa teachers:* — menu Teachers hilang", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    refute body =~ ~s(href="/teachers")
  end
end
