defmodule StellarWeb.Api.JobManagementControllerTest do
  use StellarWeb.ConnCase, async: false
  import StellarWeb.JobFixtures

  setup do
    employer = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    %{employer: employer, org: org}
  end

  test "employer creates a draft with server-owned organization and creator", %{
    conn: conn,
    employer: user,
    org: org
  } do
    values =
      attrs(%{
        "organization_id" => org.id,
        "created_by" => Ecto.UUID.generate(),
        "synthetic" => true
      })

    body = conn |> auth(user) |> post(~p"/api/jobs", values) |> json_response(201)
    assert body["data"]["organization_id"] == org.id
    assert body["data"]["status"] == "draft"
    assert body["data"]["synthetic"] == false
    job = Ash.get!(StellarJob.Job, body["data"]["id"], authorize?: false)
    assert job.created_by == user.id
  end

  test "students and employers in other tenants cannot post", %{conn: conn, org: org} do
    student = user!()
    grant!(student, org, "graduate")

    assert conn
           |> auth(student)
           |> post(~p"/api/jobs", attrs(%{"organization_id" => org.id}))
           |> json_response(403)

    stranger = user!()

    assert conn
           |> auth(stranger)
           |> post(~p"/api/jobs", attrs(%{"organization_id" => org.id}))
           |> json_response(403)
  end

  test "invalid data produces actionable validation fields", %{
    conn: conn,
    employer: user,
    org: org
  } do
    for overrides <- [
          %{"title" => " "},
          %{"employment_type" => "other"},
          %{"salary_max" => 1},
          %{"salary_min" => -1},
          %{"currency" => "INVALID"}
        ] do
      values = attrs(Map.put(overrides, "organization_id", org.id))
      assert conn |> auth(user) |> post(~p"/api/jobs", values) |> json_response(422)
    end
  end

  test "salary may be undisclosed", %{conn: conn, employer: user, org: org} do
    values = attrs(%{"organization_id" => org.id, "salary_min" => nil, "salary_max" => nil})
    assert conn |> auth(user) |> post(~p"/api/jobs", values) |> json_response(201)
  end

  test "employer edits own listings but cannot transfer ownership", %{
    conn: conn,
    employer: user,
    org: org
  } do
    job = job!(org, user)
    other = organization!(user)

    body =
      conn
      |> auth(user)
      |> patch(~p"/api/jobs/#{job.id}", %{title: "Updated role", organization_id: other.id})
      |> json_response(200)

    assert body["data"]["title"] == "Updated role"
    assert body["data"]["organization_id"] == org.id
    assert conn |> auth(user) |> delete(~p"/api/jobs/#{job.id}") |> response(204) == ""
  end

  test "other tenants cannot edit or delete listings", %{conn: conn, employer: user, org: org} do
    foreign = job!(organization!(user), user)

    assert conn
           |> auth(user)
           |> patch(~p"/api/jobs/#{foreign.id}", %{title: "Stolen"})
           |> json_response(404)

    assert conn |> auth(user) |> delete(~p"/api/jobs/#{foreign.id}") |> json_response(404)
    assert Ash.get!(StellarJob.Job, foreign.id, authorize?: false)
    own = job!(org, user)
    student = user!()
    grant!(student, org, "graduate")
    assert conn |> auth(student) |> delete(~p"/api/jobs/#{own.id}") |> json_response(403)
  end

  test "employer management scope includes drafts and expired listings", %{
    conn: conn,
    employer: user,
    org: org
  } do
    draft = job!(org, user, %{"status" => "draft"})
    expired = job!(org, user, %{"status" => "expired"})
    body = conn |> auth(user) |> get(~p"/api/jobs", %{scope: "manage"}) |> json_response(200)
    assert MapSet.new(Enum.map(body["data"], & &1["id"])) == MapSet.new([draft.id, expired.id])
  end

  test "explicit publication stamps the server time and ignores forged timestamps", %{
    conn: conn,
    employer: user,
    org: org
  } do
    created =
      conn
      |> auth(user)
      |> post(~p"/api/jobs", attrs(%{"organization_id" => org.id}))
      |> json_response(201)

    id = created["data"]["id"]
    assert created["data"]["posted_at"] == nil

    published =
      conn
      |> auth(user)
      |> patch(~p"/api/jobs/#{id}", %{status: "active", posted_at: "2099-01-01T00:00:00Z"})
      |> json_response(200)

    assert published["data"]["status"] == "active"
    {:ok, posted, _} = DateTime.from_iso8601(published["data"]["posted_at"])
    assert abs(DateTime.diff(posted, DateTime.utc_now())) < 30
  end

  test "platform superusers can read and manage across organizations", %{
    conn: conn,
    employer: employer,
    org: org
  } do
    superuser =
      user!()
      |> Ash.Changeset.for_update(:update, %{is_superuser: true})
      |> Ash.update!(authorize?: false)

    job = job!(org, employer)
    body = conn |> auth(superuser) |> get(~p"/api/jobs") |> json_response(200)
    assert Enum.any?(body["data"], &(&1["id"] == job.id))

    assert conn
           |> auth(superuser)
           |> patch(~p"/api/jobs/#{job.id}", %{title: "Admin edit"})
           |> json_response(200)
  end
end
