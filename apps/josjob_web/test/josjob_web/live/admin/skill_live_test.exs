defmodule JosjobWeb.Admin.SkillLiveTest do
  @moduledoc """
  Pilot LiveView Skills: gate superuser (LiveAuth), list + search/filter live
  dengan state di URL, form modal (Task 2), delete (Task 2).
  """
  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Industry, Skill}

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_industry(name) do
    Industry
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  defp create_skill(name, industry \\ nil) do
    Skill
    |> Ash.Changeset.for_create(:create, %{name: name, industry_id: industry && industry.id})
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

  test "non-superuser di-redirect ke / dengan flash error", %{conn: _} do
    biasa = create_user("biasa@gmail.com", "User Biasa")
    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/skills")
  end

  test "list tampil; search & filter industri menyaring + menulis URL", %{conn: conn} do
    las = create_industry("Las")
    create_skill("Welding Dasar", las)
    create_skill("Housekeeping")

    {:ok, view, html} = live(conn, ~p"/skills")
    assert html =~ "Welding Dasar"
    assert html =~ "Housekeeping"

    # search live: menyaring + patch URL
    view |> element("#skill-filter") |> render_change(%{"q" => "Weld", "industry_id" => ""})
    assert_patch(view, ~p"/skills?q=Weld")
    html = render(view)
    assert html =~ "Welding Dasar"
    refute html =~ "Housekeeping"

    # filter industri live
    view |> element("#skill-filter") |> render_change(%{"q" => "", "industry_id" => las.id})
    assert_patch(view, ~p"/skills?industry_id=#{las.id}")
    html = render(view)
    assert html =~ "Welding Dasar"
    refute html =~ "Housekeeping"
  end

  test "buka /skills dengan query param langsung tersaring", %{conn: conn} do
    create_skill("Welding Dasar")
    create_skill("Housekeeping")

    {:ok, _view, html} = live(conn, ~p"/skills?q=House")
    assert html =~ "Housekeeping"
    refute html =~ "Welding Dasar"
  end

  test "modal new: submit valid membuat skill; invalid menampilkan error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/skills/new")
    assert has_element?(view, "#skill-modal")

    # invalid: nama kosong -> error tampil, modal tetap
    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "", "industry_id" => ""}})

    assert has_element?(view, "#skill-modal")
    assert render(view) =~ "is required"

    # valid -> patch ke index, skill tampil + flash
    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Welding Lanjut", "industry_id" => ""}})

    assert_patch(view, ~p"/skills")
    html = render(view)
    assert html =~ "Welding Lanjut"
    assert html =~ "created"
  end

  test "modal edit: mengubah nama", %{conn: conn} do
    skill = create_skill("Nama Lama")

    {:ok, view, _} = live(conn, ~p"/skills/#{skill.id}/edit")
    assert has_element?(view, "#skill-modal")

    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Nama Baru", "industry_id" => ""}})

    assert_patch(view, ~p"/skills")
    html = render(view)
    assert html =~ "Nama Baru"
    refute html =~ "Nama Lama"
  end

  test "delete menghapus dari list", %{conn: conn} do
    skill = create_skill("Akan Dihapus")

    {:ok, view, html} = live(conn, ~p"/skills")
    assert html =~ "Akan Dihapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{skill.id}"]}) |> render_click()

    # nama masih muncul di FLASH ("Skill ... deleted.") — cek baris tabelnya saja
    refute has_element?(view, "#skills td", "Akan Dihapus")
    assert render(view) =~ "deleted"
  end

  test "filter terjaga setelah save dari modal", %{conn: conn} do
    create_skill("Welding Dasar")

    {:ok, view, _} = live(conn, ~p"/skills?q=Weld")
    view |> element("a", "New skill") |> render_click()
    assert_patch(view, ~p"/skills/new?q=Weld")

    view
    |> element("#skill-modal form")
    |> render_submit(%{"skill" => %{"name" => "Welding Lanjut", "industry_id" => ""}})

    assert_patch(view, ~p"/skills?q=Weld")
    html = render(view)
    assert html =~ "Welding Lanjut"
  end
end
