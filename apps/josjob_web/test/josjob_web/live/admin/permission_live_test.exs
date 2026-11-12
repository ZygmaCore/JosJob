defmodule JosjobWeb.Admin.PermissionLiveTest do
  @moduledoc """
  Menu Permissions versi LiveView (pola pilot Skills): list + search live
  (key/category/description) + pagination di URL + form modal + delete.
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Rbac.Permission

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_permission(key, attrs \\ %{}) do
    Permission
    |> Ash.Changeset.for_create(:create, Map.merge(%{key: key}, attrs))
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

  test "non-superuser di-redirect", %{conn: _} do
    biasa = create_user("biasa@gmail.com", "User Biasa")
    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/permissions")
  end

  test "search live menyaring key/category/description + URL", %{conn: conn} do
    create_permission("classes:read", %{category: "learning"})
    create_permission("jobs:post", %{category: "jobs", description: "Pasang lowongan"})

    {:ok, view, html} = live(conn, ~p"/permissions")
    assert html =~ "classes:read"
    assert html =~ "jobs:post"

    view
    |> element("#permission-filter")
    |> render_change(%{"q" => "learning", "per_page" => "10"})

    assert_patch(view, ~p"/permissions?q=learning")
    html = render(view)
    assert html =~ "classes:read"
    refute html =~ "jobs:post"
  end

  test "pagination: per_page & pindah halaman lewat URL", %{conn: conn} do
    for i <- 1..12, do: create_permission("perm#{String.pad_leading("#{i}", 2, "0")}:read")

    {:ok, view, html} = live(conn, ~p"/permissions")
    # default 10/halaman, sort key asc -> perm11 ada di halaman 2
    assert html =~ "perm01:read"
    refute html =~ "perm11:read"
    assert html =~ "Page 1 of 2"

    view |> element("a", "Next »") |> render_click()
    assert_patch(view, ~p"/permissions?page=2")
    html = render(view)
    assert html =~ "perm11:read"
    refute html =~ "perm01:read"

    # per_page 20 -> semua muat di 1 halaman
    view |> element("#permission-filter") |> render_change(%{"q" => "", "per_page" => "20"})
    assert_patch(view, ~p"/permissions?per_page=20")
    html = render(view)
    assert html =~ "perm01:read"
    assert html =~ "perm11:read"
  end

  test "modal new: create; invalid menampilkan error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/permissions/new")
    assert has_element?(view, "#permission-modal")

    view
    |> element("#permission-modal form")
    |> render_submit(%{"permission" => %{"key" => "", "category" => "", "description" => ""}})

    assert has_element?(view, "#permission-modal")
    assert render(view) =~ "is required"

    view
    |> element("#permission-modal form")
    |> render_submit(%{
      "permission" => %{"key" => "reports:read", "category" => "reports", "description" => ""}
    })

    assert_patch(view, ~p"/permissions")
    html = render(view)
    assert html =~ "reports:read"
    assert html =~ "created"
  end

  test "modal edit: mengubah description", %{conn: conn} do
    perm = create_permission("classes:read", %{description: "Lama"})

    {:ok, view, _} = live(conn, ~p"/permissions/#{perm.id}/edit")

    view
    |> element("#permission-modal form")
    |> render_submit(%{
      "permission" => %{"key" => "classes:read", "category" => "", "description" => "Baru"}
    })

    assert_patch(view, ~p"/permissions")
    html = render(view)
    assert html =~ "Baru"
    refute html =~ "Lama"
  end

  test "delete menghapus dari list", %{conn: conn} do
    perm = create_permission("hapus:read")

    {:ok, view, html} = live(conn, ~p"/permissions")
    assert html =~ "hapus:read"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{perm.id}"]}) |> render_click()

    refute has_element?(view, "#permissions td", "hapus:read")
    assert render(view) =~ "deleted"
  end
end
