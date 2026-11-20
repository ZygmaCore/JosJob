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
    assert data["semantic"] == true
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
             conn |> auth(user) |> post(~p"/api/rag/cv/extractions", %{}),
             400
           )["fields"]["file"]
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
