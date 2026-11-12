defmodule JosjobWeb.MyDocumentLiveTest do
  @moduledoc """
  Portal My Documents versi LiveView: list `visible_to` user, upload (modal,
  user_id dipaksa dirinya), delete hanya milik sendiri / admin-org / superuser.
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Membership, Organization}
  alias JosjobDoc.Documents.Document

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

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  setup %{conn: _conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)

    member = create_user("member@gmail.com", "Member Uji")
    create_membership(member, org)

    {:ok,
     conn: login(Phoenix.ConnTest.build_conn(), member),
     member: member,
     org: org,
     superuser: superuser}
  end

  test "bukan member di-redirect" do
    orang = create_user("orang@gmail.com", "Tanpa Membership")
    conn = login(Phoenix.ConnTest.build_conn(), orang)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/my/documents")
  end

  test "list hanya dokumen visible; upload memaksa user_id dirinya",
       %{conn: conn, member: member, org: org, superuser: su} do
    create_document("punya-sendiri", member, org)
    create_document("punya-orang", su, org)

    {:ok, view, html} = live(conn, ~p"/my/documents")
    assert html =~ "punya-sendiri"
    # member biasa (bukan admin-org) tidak melihat dokumen orang lain
    refute html =~ "punya-orang"

    {:ok, view, _} = live(conn, ~p"/my/documents/new")
    assert has_element?(view, "#my-document-modal")

    view
    |> element("#my-document-modal form")
    |> render_submit(%{
      "document" => %{
        "title" => "unggahan-baru",
        "url" => "https://files.example.com/baru.pdf",
        "organization_id" => org.id,
        "mime_type" => "",
        "description" => ""
      }
    })

    assert_patch(view, ~p"/my/documents")
    assert render(view) =~ "unggahan-baru"

    created =
      Document |> Ash.Query.filter(title == "unggahan-baru") |> Ash.read_one!(authorize?: false)

    assert created.user_id == member.id
  end

  test "delete milik sendiri OK; milik orang lain ditolak",
       %{conn: conn, member: member, org: org, superuser: su} do
    milik = create_document("milikku", member, org)
    orang = create_document("milik-orang", su, org)

    {:ok, view, _} = live(conn, ~p"/my/documents")

    view |> element(~s{[phx-click="delete"][phx-value-id="#{milik.id}"]}) |> render_click()
    refute has_element?(view, "#my-documents td", "milikku")

    # dokumen orang lain tak tampil di list member biasa -> uji guard via event langsung
    render_click(view, "delete", %{"id" => orang.id})
    assert render(view) =~ "can&#39;t delete"
    assert Ash.get!(Document, orang.id, authorize?: false)
  end
end
