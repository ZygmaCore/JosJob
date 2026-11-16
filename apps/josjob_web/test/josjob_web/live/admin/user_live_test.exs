defmodule JosjobWeb.Admin.UserLiveTest do
  @moduledoc """
  Menu Users versi LiveView (superuser only): list + search live (nama/email)
  + form modal (termasuk checkbox superuser) + delete (bersihkan identity dulu).
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
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

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    {:ok, conn: login(conn, superuser)}
  end

  test "non-superuser di-redirect" do
    biasa = create_user("biasa@gmail.com", "User Biasa")
    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users")
  end

  test "list + search live (nama/email) + URL", %{conn: conn} do
    create_user("andi@gmail.com", "Andi Wijaya")
    create_user("budi@gmail.com", "Budi Santoso")

    {:ok, view, html} = live(conn, ~p"/users")
    assert html =~ "Andi Wijaya"
    assert html =~ "Budi Santoso"

    view |> element("#user-filter") |> render_change(%{"q" => "andi"})
    assert_patch(view, ~p"/users?q=andi")
    html = render(view)
    assert html =~ "Andi Wijaya"
    refute html =~ "Budi Santoso"
  end

  test "modal new: create user; invalid menampilkan error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/users/new")
    assert has_element?(view, "#user-modal")

    view
    |> element("#user-modal form")
    |> render_submit(%{"user" => %{"email" => "", "full_name" => ""}})

    assert has_element?(view, "#user-modal")
    assert render(view) =~ "is required"

    view
    |> element("#user-modal form")
    |> render_submit(%{
      "user" => %{"email" => "baru@gmail.com", "full_name" => "User Baru"}
    })

    assert_patch(view, ~p"/users")
    assert render(view) =~ "User Baru"

    created =
      User |> Ash.Query.filter(full_name == "User Baru") |> Ash.read_one!(authorize?: false)

    assert created.is_superuser == false
  end

  test "modal edit: mengubah nama", %{conn: conn} do
    user = create_user("target@gmail.com", "Nama Lama")

    {:ok, view, _} = live(conn, ~p"/users/#{user.id}/edit")

    view
    |> element("#user-modal form")
    |> render_submit(%{"user" => %{"email" => "target@gmail.com", "full_name" => "Nama Baru"}})

    assert_patch(view, ~p"/users")
    html = render(view)
    assert html =~ "Nama Baru"
    refute html =~ "Nama Lama"
  end

  test "delete menghapus user", %{conn: conn} do
    user = create_user("hapus@gmail.com", "Akan Dihapus")

    {:ok, view, html} = live(conn, ~p"/users")
    assert html =~ "Akan Dihapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{user.id}"]}) |> render_click()

    refute has_element?(view, "#users td", "Akan Dihapus")
    assert render(view) =~ "deleted"
  end
end
