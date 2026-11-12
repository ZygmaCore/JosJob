defmodule StellarWeb.Api.JobListingControllerTest do
  use StellarWeb.ConnCase, async: false
  import StellarWeb.JobFixtures

  setup do
    employer = user!()
    student = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    grant!(student, org, "graduate")
    job = job!(org, employer)
    %{student: student, employer: employer, org: org, job: job}
  end

  test "requires authentication", %{conn: conn} do
    assert json_response(get(conn, ~p"/api/jobs"), 401)["error"] == "unauthorized"
  end

  test "lists active jobs in authorized organizations only", %{
    conn: conn,
    student: user,
    employer: employer,
    org: org,
    job: job
  } do
    job!(org, employer, %{"status" => "draft", "title" => "Private draft"})
    other = organization!(employer, "Other tenant")
    job!(other, employer, %{"title" => "Secret tenant job"})
    body = conn |> auth(user) |> get(~p"/api/jobs") |> json_response(200)
    assert Enum.map(body["data"], & &1["id"]) == [job.id]
    assert body["meta"]["total"] == 1
    assert hd(body["data"])["can_manage"] == false
    refute Map.has_key?(hd(body["data"]), "match_score")
  end

  test "shows details but masks drafts and other tenants with 404", %{
    conn: conn,
    student: user,
    employer: employer,
    org: org,
    job: job
  } do
    body = conn |> auth(user) |> get(~p"/api/jobs/#{job.id}") |> json_response(200)
    assert body["data"]["requirements"] == ["Elixir", "SQL"]
    draft = job!(org, employer, %{"status" => "draft"})
    assert conn |> auth(user) |> get(~p"/api/jobs/#{draft.id}") |> json_response(404)
    foreign = job!(organization!(employer), employer)
    assert conn |> auth(user) |> get(~p"/api/jobs/#{foreign.id}") |> json_response(404)
    assert conn |> auth(user) |> get(~p"/api/jobs/not-a-uuid") |> json_response(404)
  end

  test "search and combined filters run on the server", %{
    conn: conn,
    student: user,
    org: org,
    employer: employer
  } do
    remote =
      job!(org, employer, %{
        "title" => "Backend engineer",
        "work_mode" => "remote",
        "location" => "Jakarta"
      })

    params = %{
      q: "BACKEND",
      work_mode: "remote",
      location: "jak",
      industry: "TECH",
      employment_type: "full-time",
      salary_min: "7000000",
      currency: "IDR"
    }

    body = conn |> auth(user) |> get(~p"/api/jobs", params) |> json_response(200)
    assert Enum.map(body["data"], & &1["id"]) == [remote.id]
  end

  test "salary sorting and pagination use a stable order", %{
    conn: conn,
    student: user,
    org: org,
    employer: employer,
    job: low
  } do
    high = job!(org, employer, %{"salary_max" => 12_000_000})

    first =
      conn
      |> auth(user)
      |> get(~p"/api/jobs", %{sort: "salary", currency: "IDR", page_size: "1"})
      |> json_response(200)

    second =
      conn
      |> auth(user)
      |> get(~p"/api/jobs", %{sort: "salary", currency: "IDR", page_size: "1", page: "2"})
      |> json_response(200)

    assert hd(first["data"])["id"] == high.id
    assert hd(second["data"])["id"] == low.id
    assert first["meta"]["total_pages"] == 2
  end

  test "rejects malformed filters and bounded pagination", %{conn: conn, student: user} do
    for params <- [
          %{page: "-1"},
          %{page_size: "999"},
          %{salary_min: "abc"},
          %{work_mode: "invented"},
          %{q: ["bad"]}
        ] do
      assert conn |> auth(user) |> get(~p"/api/jobs", params) |> json_response(400)
    end
  end

  test "unprovisioned users see an honest empty result", %{conn: conn} do
    body = conn |> auth(user!()) |> get(~p"/api/jobs") |> json_response(200)
    assert body["data"] == []
    assert body["meta"]["total"] == 0
  end

  test "students cannot use management scope to reveal drafts", %{
    conn: conn,
    student: user,
    org: org,
    employer: employer
  } do
    job!(org, employer, %{"status" => "draft"})
    body = conn |> auth(user) |> get(~p"/api/jobs", %{scope: "manage"}) |> json_response(200)
    assert body["data"] == []
  end
end
