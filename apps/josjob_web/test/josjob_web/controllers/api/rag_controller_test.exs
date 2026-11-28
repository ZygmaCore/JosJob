defmodule JosjobWeb.Api.RagControllerTest do
  use JosjobWeb.ConnCase, async: false

  import JosjobWeb.JobFixtures

  setup do
    user = user!()
    org = organization!(user)
    grant!(user, org, "graduate")
    job = job!(org, user)
    %{user: user, org: org, job: job}
  end

  defp post_json(conn, path, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(params))
  end

  test "requires authentication", %{conn: conn} do
    assert json_response(
             post_json(conn, ~p"/api/rag/analyses", %{"cv_id" => "cv-1", "skills" => ["Elixir"]}),
             401
           )["error"] == "unauthorized"
  end

  test "ranks a structured CV, hints real courses only, and persists the snapshot", %{
    conn: conn,
    user: user,
    job: job
  } do
    body =
      conn
      |> auth(user)
      |> post_json(~p"/api/rag/analyses", %{
        "cv_id" => "cv-api-1",
        "skills" => ["Elixir"],
        "limit" => 5
      })
      |> json_response(200)

    data = body["data"]
    assert data["cv_id"] == "cv-api-1"
    assert data["semantic"] == false
    assert data["provider"] == "local"
    assert data["persisted"] == true
    assert is_binary(data["analysis_id"])

    assert [match | _] = data["jobs"]
    assert match["job_id"] == job.id
    assert match["job"]["title"] == job.title
    assert is_float(match["match_score"])
    assert match["missing_skills"] == ["SQL"]
    assert match["explanation"] =~ "skill"
    assert match["course"] == nil

    assert data["courses"] == []

    persisted =
      conn
      |> auth(user)
      |> get(~p"/api/rag/analyses/cv-api-1")
      |> json_response(200)

    assert persisted["data"]["cv_id"] == "cv-api-1"
    assert [stored] = persisted["data"]["jobs"]
    assert stored["job_id"] == job.id
    assert stored["missing_skills"] == ["SQL"]
  end

  test "rejects a CV without an id or without any structured content", %{
    conn: conn,
    user: user
  } do
    missing_id =
      conn
      |> auth(user)
      |> post_json(~p"/api/rag/analyses", %{"skills" => ["Elixir"]})
      |> json_response(400)

    assert missing_id["fields"]["cv_id"]

    empty =
      conn
      |> auth(user)
      |> post_json(~p"/api/rag/analyses", %{
        "cv_id" => "cv-empty",
        "skills" => [],
        "experience" => [],
        "education" => []
      })
      |> json_response(400)

    assert empty["fields"]["cv"]
  end

  test "unknown persisted analyses return 404", %{conn: conn, user: user} do
    assert json_response(
             conn |> auth(user) |> get(~p"/api/rag/analyses/never-seen"),
             404
           )["error"] == "not_found"
  end

  test "extraction uploads require a multipart file", %{conn: conn, user: user} do
    assert json_response(
             conn |> auth(user) |> post(~p"/api/rag/cv/extractions", %{"consent" => true}),
             400
           )["fields"]["file"]
  end

  defp extraction_response(data) do
    previous = Application.get_env(:josjob_rag, :pdf_service, [])

    Application.put_env(:josjob_rag, :pdf_service,
      http_client: fn _request -> {:ok, %{status: 200, body: %{"data" => data}}} end
    )

    on_exit(fn -> Application.put_env(:josjob_rag, :pdf_service, previous) end)
  end

  test "requires explicit consent before submitting a PDF", %{conn: conn, user: user} do
    response = conn |> auth(user) |> post(~p"/api/rag/cv/extractions", %{}) |> json_response(400)
    assert response["fields"]["consent"]
  end

  test "upload forwards the authenticated owner and known listing skills", %{
    conn: conn,
    user: user
  } do
    parent = self()
    previous = Application.get_env(:josjob_rag, :pdf_service, [])

    Application.put_env(:josjob_rag, :pdf_service,
      http_client: fn request ->
        send(parent, {:pdf_upload, request})
        {:ok, %{status: 202, body: %{"data" => %{"id" => "new", "status" => "queued"}}}}
      end
    )

    on_exit(fn -> Application.put_env(:josjob_rag, :pdf_service, previous) end)
    path = Path.join(System.tmp_dir!(), "api-cv-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "%PDF-1.4 synthetic")
    on_exit(fn -> File.rm(path) end)
    upload = %Plug.Upload{path: path, filename: "cv.pdf", content_type: "application/pdf"}

    assert conn
           |> auth(user)
           |> post(~p"/api/rag/cv/extractions", %{
             "file" => upload,
             "consent" => "true",
             "user_id" => "forged"
           })
           |> json_response(202)

    assert_receive {:pdf_upload, request}
    assert request[:form_multipart][:user_id] == user.id
    assert "Elixir" in Jason.decode!(request[:form_multipart][:known_skills])
  end

  test "extractions without ownership metadata fail closed", %{conn: conn, user: user} do
    extraction_response(%{"status" => "done", "result" => %{"skills" => ["Elixir"]}})
    assert conn |> auth(user) |> get(~p"/api/rag/cv/extractions/legacy") |> json_response(404)
  end

  test "extraction contents cannot be read or ranked by another user", %{conn: conn, user: user} do
    extraction_response(%{
      "user_id" => "another-user",
      "status" => "done",
      "result" => %{"skills" => ["Elixir"]}
    })

    assert conn |> auth(user) |> get(~p"/api/rag/cv/extractions/private") |> json_response(404)

    assert conn
           |> auth(user)
           |> post_json(~p"/api/rag/analyses", %{"extraction_id" => "private"})
           |> json_response(404)
  end

  test "failed and unreadable extractions are terminal errors rather than pending", %{
    conn: conn,
    user: user
  } do
    for status <- ["failed", "unreadable", "cancelled"] do
      extraction_response(%{"user_id" => user.id, "status" => status})

      response =
        conn
        |> auth(user)
        |> post_json(~p"/api/rag/analyses", %{"extraction_id" => "bad"})
        |> json_response(422)

      assert response["error"] == "extraction_failed"
    end
  end

  test "an owned completed extraction produces job rankings", %{conn: conn, user: user, job: job} do
    extraction_response(%{
      "user_id" => user.id,
      "cv_id" => "uploaded-cv",
      "status" => "done",
      "result" => %{"skills" => ["Elixir", "SQL"]}
    })

    response =
      conn
      |> auth(user)
      |> post_json(~p"/api/rag/analyses", %{"extraction_id" => "owned"})
      |> json_response(200)

    assert response["data"]["cv_id"] == "uploaded-cv"
    assert [match | _] = response["data"]["jobs"]
    assert match["job_id"] == job.id
    assert match["missing_skills"] == []
  end

  test "reindex is superuser-only", %{conn: conn, user: user} do
    assert json_response(
             conn |> auth(user) |> post_json(~p"/api/rag/reindex", %{}),
             403
           )["error"] == "forbidden"

    assert json_response(post_json(conn, ~p"/api/rag/reindex", %{}), 401)["error"] ==
             "unauthorized"
  end
end
