defmodule JosjobWeb.Api.JobListingControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures

  setup do
    employer = user!()
    student = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    grant!(student, org, "graduate")
    job = job!(org, employer)
    %{student: student, employer: employer, org: org, job: job}
  end

  test "visitors can list and open published vacancies without organization access", c do
    body = c.conn |> get(~p"/api/jobs") |> json_response(200)
    assert [%{"id" => id, "can_manage" => false}] = body["data"]
    assert id == c.job.id
    assert body["organizations"] == []
    assert c.conn |> get(~p"/api/jobs/#{id}") |> json_response(200)
    assert c.conn |> get(~p"/api/jobs", %{scope: "manage"}) |> json_response(401)
  end

  test "lists active jobs across organizations and hides unpublished vacancies", %{
    conn: conn,
    student: user,
    employer: employer,
    org: org,
    job: job
  } do
    job!(org, employer, %{"status" => "draft", "title" => "Private draft"})
    other = organization!(employer, "Other tenant")
    foreign = job!(other, employer, %{"title" => "Public vacancy"})
    body = conn |> auth(user) |> get(~p"/api/jobs") |> json_response(200)
    assert MapSet.new(Enum.map(body["data"], & &1["id"])) == MapSet.new([job.id, foreign.id])
    assert body["meta"]["total"] == 2
    assert hd(body["data"])["can_manage"] == false
    refute Map.has_key?(hd(body["data"]), "match_score")
  end

  test "shows published details across organizations but hides drafts and expired listings", %{
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
    assert conn |> auth(user) |> get(~p"/api/jobs/#{foreign.id}") |> json_response(200)
    expired = job!(org, employer, %{"status" => "expired"})

    for hidden <- [draft, expired] do
      assert conn |> get(~p"/api/jobs/#{hidden.id}") |> json_response(404)
      assert conn |> auth(user!()) |> get(~p"/api/jobs/#{hidden.id}") |> json_response(404)
    end

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

  test "new users browse without provisioning and have no employer capabilities", %{
    conn: conn,
    job: job
  } do
    body = conn |> auth(user!()) |> get(~p"/api/jobs") |> json_response(200)
    assert [%{"id" => id, "can_manage" => false}] = body["data"]
    assert id == job.id
    assert body["meta"]["total"] == 1
    assert body["organizations"] == []
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

  test "public reads reject invalid and refresh credentials, while writes remain authenticated",
       c do
    {:ok, tokens} = Josjob.Accounts.Tokens.issue_pair(c.student)

    for token <- ["invalid-token", tokens.refresh_token] do
      conn = Plug.Conn.put_req_header(c.conn, "authorization", "Bearer #{token}")
      assert conn |> get(~p"/api/jobs") |> json_response(401)
      assert conn |> get(~p"/api/jobs/#{c.job.id}") |> json_response(401)
    end

    assert c.conn |> post(~p"/api/jobs", attrs()) |> json_response(401)
    assert c.conn |> patch(~p"/api/jobs/#{c.job.id}", %{title: "Changed"}) |> json_response(401)
    assert c.conn |> delete(~p"/api/jobs/#{c.job.id}") |> json_response(401)

    assert c.conn
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true})
           |> json_response(401)

    assert c.conn |> get(~p"/api/applications") |> json_response(401)

    assert c.conn
           |> get(~p"/api/chats/application/#{Ecto.UUID.generate()}/messages")
           |> json_response(401)
  end
end
