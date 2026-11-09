defmodule StellarWeb.Admin.IndustryLiveTest do
  @moduledoc """
  Menu Industries versi LiveView (pola pilot Skills): list + search live (URL)
  + form modal (parent select, exclude diri sendiri saat edit) + delete.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.Industry

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_industry(name, attrs \\ %{}) do
    Industry
    |> Ash.Changeset.for_create(:create, Map.merge(%{name: name}, attrs))
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

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/industries")
  end

  test "list + search live menyaring + URL; kolom Parent tampil", %{conn: conn} do
    induk = create_industry("Manufaktur")
    create_industry("Otomotif", %{parent_id: induk.id})
    create_industry("Pariwisata")

    {:ok, view, html} = live(conn, ~p"/industries")
    assert html =~ "Otomotif"
    assert html =~ "Pariwisata"

    view |> element("#industry-filter") |> render_change(%{"q" => "Oto"})
    assert_patch(view, ~p"/industries?q=Oto")
    html = render(view)
    assert html =~ "Otomotif"
    # nama induk tampil di kolom Parent baris Otomotif
    assert html =~ "Manufaktur"
    refute html =~ "Pariwisata"
  end

  test "modal new: create dengan parent; invalid menampilkan error", %{conn: conn} do
    induk = create_industry("Manufaktur")

    {:ok, view, _} = live(conn, ~p"/industries/new")
    assert has_element?(view, "#industry-modal")

    view
    |> element("#industry-modal form")
    |> render_submit(%{"industry" => %{"name" => "", "parent_id" => ""}})

    assert has_element?(view, "#industry-modal")
    assert render(view) =~ "is required"

    view
    |> element("#industry-modal form")
    |> render_submit(%{"industry" => %{"name" => "Otomotif", "parent_id" => induk.id}})

    assert_patch(view, ~p"/industries")
    assert render(view) =~ "Otomotif"

    created = Industry |> Ash.Query.filter(name == "Otomotif") |> Ash.read_one!(authorize?: false)
    assert created.parent_id == induk.id
  end

  test "modal edit: dropdown parent tidak menawarkan dirinya sendiri", %{conn: conn} do
    a = create_industry("Alfa")
    _b = create_industry("Beta")

    {:ok, view, _} = live(conn, ~p"/industries/#{a.id}/edit")

    [select] =
      Regex.run(~r/<select[^>]*name="industry\[parent_id\]".*?<\/select>/s, render(view))

    refute select =~ a.id
    assert select =~ "Beta"

    view
    |> element("#industry-modal form")
    |> render_submit(%{"industry" => %{"name" => "Alfa Baru", "parent_id" => ""}})

    assert_patch(view, ~p"/industries")
    assert render(view) =~ "Alfa Baru"
  end

  test "delete menghapus dari list", %{conn: conn} do
    industry = create_industry("Akan Dihapus")

    {:ok, view, html} = live(conn, ~p"/industries")
    assert html =~ "Akan Dihapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{industry.id}"]}) |> render_click()

    refute has_element?(view, "#industries td", "Akan Dihapus")
    assert render(view) =~ "deleted"
  end
end
