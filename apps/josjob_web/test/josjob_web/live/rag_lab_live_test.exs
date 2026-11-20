defmodule JosjobWeb.RagLabLiveTest do
  @moduledoc """
  Lab RAG: upload PDF → polling ekstraksi → ranking + course.

  Service eksternal (ragpdf) dan analyzer di-stub karena ini unit test
  LiveView; pipeline asli sudah diverifikasi live lewat HTTP API.
  """

  use JosjobWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import JosjobWeb.JobFixtures

  setup %{conn: _conn} do
    previous = %{
      pdf: Application.get_env(:josjob_web, :rag_lab_pdf_client),
      analyzer: Application.get_env(:josjob_web, :rag_lab_analyzer)
    }

    Application.put_env(:josjob_web, :rag_lab_pdf_client, JosjobWeb.RagLabPdfStub)
    Application.put_env(:josjob_web, :rag_lab_analyzer, JosjobWeb.RagLabAnalyzerStub)

    on_exit(fn ->
      restore_env(:rag_lab_pdf_client, previous.pdf)
      restore_env(:rag_lab_analyzer, previous.analyzer)
    end)

    user = user!()
    {:ok, conn: login(build_conn(), user), user: user}
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  defp restore_env(key, nil), do: Application.delete_env(:josjob_web, key)
  defp restore_env(key, value), do: Application.put_env(:josjob_web, key, value)

  test "redirects to / when not logged in" do
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), ~p"/rag/lab")
  end

  test "renders the upload form for any logged-in user", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rag/lab")

    assert has_element?(view, "#rag-lab-form")
    assert has_element?(view, "#rag-lab-submit")
    assert render(view) =~ "RAG Lab"
  end

  test "asks for a file when the form is empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rag/lab")

    html =
      view
      |> form("#rag-lab-form")
      |> render_submit()

    assert html =~ "Pilih satu file PDF CV dulu."
    assert has_element?(view, "#rag-lab-error")
  end

  test "uploads a PDF, polls extraction, then renders ranking + course", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/rag/lab")

    view
    |> file_input("#rag-lab-form", :cv, [
      %{name: "cv.pdf", content: "%PDF-1.4 test", type: "application/pdf"}
    ])
    |> render_upload("cv.pdf")

    html =
      view
      |> form("#rag-lab-form")
      |> render_submit()

    assert html =~ "Mengekstrak CV"

    send(view.pid, {:poll, "job_stub"})
    html = render(view)

    assert html =~ "semantic ranking aktif"
    assert html =~ "Backend Engineer"
    assert html =~ "PT Uji"
    assert html =~ "Kubernetes"
    assert html =~ "Kubernetes Dasar"
    assert has_element?(view, "#rag-lab-results")
  end
end
