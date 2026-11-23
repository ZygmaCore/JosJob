defmodule JosjobWeb.Api.CvRelevanceTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias JosjobRag.{Analyses, Analyzer, PdfClient}

  setup do
    user = user!()
    org = organization!(user)

    backend =
      job!(org, user, %{"title" => "Backend Developer", "requirements" => ["Elixir", "SQL"]})

    design =
      job!(org, user, %{"title" => "Product Designer", "requirements" => ["Figma", "UX Research"]})

    cv = %{"cv_id" => "saved-backend", "skills" => ["Elixir", "SQL"]}
    {:ok, result} = Analyzer.analyze(user, cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(user, cv, result)
    %{user: user, org: org, backend: backend, design: design, cv: cv}
  end

  test "normal job list orders all results by saved CV before pagination", %{
    conn: conn,
    user: user,
    backend: backend,
    design: design
  } do
    first =
      conn
      |> auth(user)
      |> get(~p"/api/jobs", %{sort: "relevance", page_size: 1})
      |> json_response(200)

    assert [best] = first["data"]
    assert best["id"] == backend.id
    assert best["relevance"]["matched_skills"] == ["Elixir", "SQL"]
    assert first["meta"]["total"] == 2
    assert first["meta"]["cv_categories"] == ["backend"]

    second =
      conn
      |> auth(user)
      |> get(~p"/api/jobs", %{sort: "relevance", page_size: 1, page: 2})
      |> json_response(200)

    assert [%{"id" => id, "relevance" => %{"relevance_label" => "Less relevant"}}] =
             second["data"]

    assert id == design.id
  end

  test "filters still apply, changing the saved CV changes the listing order", %{
    conn: conn,
    user: user,
    cv: cv,
    design: design
  } do
    cv = Map.put(cv, "skills", ["Figma", "UX Research"])
    {:ok, result} = Analyzer.analyze(user, cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(user, cv, result)

    response =
      conn
      |> auth(user)
      |> get(~p"/api/jobs", %{sort: "relevance", q: "Designer"})
      |> json_response(200)

    assert [%{"id" => id}] = response["data"]
    assert id == design.id
    assert response["meta"]["cv_categories"] == ["design"]
  end

  test "CV facts are private and absence falls back to newest browsing", %{conn: conn} do
    other = user!()
    assert conn |> get(~p"/api/jobs", %{sort: "relevance"}) |> json_response(401)

    response =
      conn |> auth(other) |> get(~p"/api/jobs", %{sort: "relevance"}) |> json_response(200)

    assert response["meta"]["relevance_status"] == "cv_required"

    assert conn
           |> auth(other)
           |> get(~p"/api/jobs", %{sort: "relevance", cv_id: "saved-backend"})
           |> json_response(404)
  end

  test "saved CV can be reranked after extraction service expires without contacting it", %{
    conn: conn,
    user: user
  } do
    previous = Application.get_env(:josjob_rag, :pdf_service, [])

    Application.put_env(:josjob_rag, :pdf_service,
      http_client: fn _ -> flunk("must not contact extraction service") end
    )

    on_exit(fn -> Application.put_env(:josjob_rag, :pdf_service, previous) end)

    response =
      conn
      |> auth(user)
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/rag/analyses", Jason.encode!(%{cv_id: "saved-backend"}))
      |> json_response(200)

    assert response["data"]["method"] == "category_skill"
    assert response["data"]["scoring"]["external_ai_calls"] == 0
  end

  test "identical owned PDF reuses saved extraction rather than calling AI again", %{
    conn: conn,
    user: user
  } do
    path = Path.join(System.tmp_dir!(), "cv-reuse-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "%PDF-1.4 synthetic")
    on_exit(fn -> File.rm(path) end)
    upload = %Plug.Upload{path: path, filename: "resume.pdf", content_type: "application/pdf"}
    {:ok, version} = PdfClient.version(upload)
    cv = %{"cv_id" => version, "skills" => ["Elixir"]}
    {:ok, result} = Analyzer.analyze(user, cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(user, cv, result)
    previous = Application.get_env(:josjob_rag, :pdf_service, [])

    Application.put_env(:josjob_rag, :pdf_service,
      http_client: fn _ -> flunk("duplicate extraction") end
    )

    on_exit(fn -> Application.put_env(:josjob_rag, :pdf_service, previous) end)

    response =
      conn
      |> auth(user)
      |> post(~p"/api/rag/cv/extractions", %{"file" => upload, "consent" => "true"})
      |> json_response(202)

    assert response["data"]["cached"]
    assert response["data"]["cv_id"] == version

    status =
      conn |> auth(user) |> get(~p"/api/rag/cv/extractions/#{version}") |> json_response(200)

    assert status["data"]["result"]["skills"] == ["Elixir"]

    assert conn
           |> auth(user!())
           |> get(~p"/api/rag/cv/extractions/#{version}")
           |> json_response(404)
  end
end
