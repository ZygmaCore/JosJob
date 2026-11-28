defmodule JosjobWeb.Admin.SectionLiveTest do
  @moduledoc """
  Menu Sections versi LiveView (pola pilot Skills): list + form modal
  (name/description/is_active) + delete. Tanpa search (mengikuti halaman lama).
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias JosjobLrn.Learning.Section

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_section(name, attrs \\ %{}) do
    Section
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

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/sections")
  end

  test "modal new: create; invalid menampilkan error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/sections/new")
    assert has_element?(view, "#section-modal")

    view
    |> element("#section-modal form")
    |> render_submit(%{"section" => %{"name" => ""}})

    assert has_element?(view, "#section-modal")
    assert render(view) =~ "is required"

    view
    |> element("#section-modal form")
    |> render_submit(%{
      "section" => %{
        "name" => "Teknik Las",
        "description" => "Jurusan las",
        "is_active" => "true"
      }
    })

    assert_patch(view, ~p"/sections")
    html = render(view)
    assert html =~ "Teknik Las"
    assert html =~ "created"
  end

  test "modal edit: menonaktifkan section (is_active false)", %{conn: conn} do
    section = create_section("Perhotelan", %{is_active: true})

    {:ok, view, _} = live(conn, ~p"/sections/#{section.id}/edit")
    assert has_element?(view, "#section-modal")

    view
    |> element("#section-modal form")
    |> render_submit(%{"section" => %{"name" => "Perhotelan", "is_active" => "false"}})

    assert_patch(view, ~p"/sections")

    assert Ash.get!(Section, section.id, authorize?: false).is_active == false
  end

  test "delete menghapus dari list", %{conn: conn} do
    section = create_section("Akan Dihapus")

    {:ok, view, html} = live(conn, ~p"/sections")
    assert html =~ "Akan Dihapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{section.id}"]}) |> render_click()

    refute has_element?(view, "#sections td", "Akan Dihapus")
    assert render(view) =~ "deleted"
  end
end
