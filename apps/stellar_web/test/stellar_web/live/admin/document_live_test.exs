defmodule StellarWeb.Admin.DocumentLiveTest do
  @moduledoc """
  Menu Documents (bank dokumen, `documents:manage`) versi LiveView: list
  ter-scope org, filter org (superuser), modal New (non-superuser dikunci ke
  org aktif + dirinya), delete ber-guard scope.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}
  alias StellarDoc.Documents.Document

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

  defp create_document(title, user, org) do
    Document
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      url: "https://files.example.com/#{title}.pdf",
      user_id: user.id,
      organization_id: org.id
    })
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

    {login(Phoenix.ConnTest.build_conn(), user), user}
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

  test "tanpa documents:manage di-redirect", %{org: org} do
    {conn, _} = staff_with_perms(org, ["dashboard:view"])

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/documents")
  end

  test "non-superuser: list ter-scope org aktif; create dikunci ke org + dirinya",
       %{superuser: su, org: org, org_b: org_b} do
    create_document("doc-alfa", su, org)
    create_document("doc-beta", su, org_b)

    {conn, staff} = staff_with_perms(org, ["documents:manage"])

    {:ok, _view, html} = live(conn, ~p"/documents")
    assert html =~ "doc-alfa"
    refute html =~ "doc-beta"

    # create: selundupkan org lain + user lain -> tetap dikunci org aktif + dirinya
    {:ok, view, _} = live(conn, ~p"/documents/new")
    assert has_element?(view, "#document-modal")

    view
    |> element("#document-modal form")
    |> render_submit(%{
      "document" => %{
        "title" => "doc-staff",
        "url" => "https://files.example.com/doc-staff.pdf",
        "user_id" => su.id,
        "organization_id" => org_b.id,
        "mime_type" => "",
        "description" => ""
      }
    })

    assert_patch(view, ~p"/documents")

    created =
      Document |> Ash.Query.filter(title == "doc-staff") |> Ash.read_one!(authorize?: false)

    assert created.organization_id == org.id
    assert created.user_id == staff.id
  end

  test "superuser: filter org lewat URL + delete", %{
    conn: conn,
    superuser: su,
    org: org,
    org_b: org_b
  } do
    doc_a = create_document("doc-alfa", su, org)
    create_document("doc-beta", su, org_b)

    {:ok, view, html} = live(conn, ~p"/documents")
    assert html =~ "doc-alfa"
    assert html =~ "doc-beta"

    view |> element("#document-filter") |> render_change(%{"organization_id" => org.id})
    assert_patch(view, ~p"/documents?organization_id=#{org.id}")
    html = render(view)
    assert html =~ "doc-alfa"
    refute html =~ "doc-beta"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{doc_a.id}"]}) |> render_click()
    refute has_element?(view, "#documents td", "doc-alfa")
    assert render(view) =~ "deleted"
  end
end
