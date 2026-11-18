defmodule JosjobWeb.Api.ApplicationControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias JosjobJob.{Applications, CurriculumVitae}

  setup do
    employer = user!()
    candidate = user!()
    org = organization!(employer)
    membership = grant!(employer, org, "employer")
    grant!(candidate, org, "graduate")
    job = job!(org, employer)
    %{employer: employer, candidate: candidate, org: org, job: job, membership: membership}
  end

  defp apply!(c, overrides \\ %{}) do
    c.conn
    |> auth(c.candidate)
    |> post(
      ~p"/api/jobs/#{c.job.id}/applications",
      Map.merge(%{"consent" => true, "cover_letter" => "I would like to contribute."}, overrides)
    )
    |> json_response(201)
    |> Map.fetch!("data")
  end

  test "submission saves an owned immutable profile and one initial event, ignoring forged ownership",
       c do
    {:ok, _} = CurriculumVitae.save_for(c.candidate, %{"headline" => "Original headline"})

    body =
      apply!(c, %{
        "candidate_id" => c.employer.id,
        "status" => "hired",
        "profile_snapshot" => %{"headline" => "Forged"}
      })

    assert body["status"] == "applied"
    assert body["profile"]["headline"] == "Original headline"
    assert body["profile"]["identity"]["email"] == to_string(c.candidate.email)
    assert [%{"status" => "applied"}] = body["history"]
    {:ok, _} = CurriculumVitae.save_for(c.candidate, %{"headline" => "Changed later"})

    saved =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/applications/#{body["id"]}")
      |> json_response(200)

    assert saved["data"]["profile"]["headline"] == "Original headline"

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true})
           |> json_response(409)
  end

  test "consent, active listing visibility and self-application restrictions are enforced", c do
    assert c.conn
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true})
           |> json_response(401)

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{})
           |> json_response(422)

    assert c.conn
           |> auth(c.employer)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true})
           |> json_response(409)

    assert c.conn
           |> auth(user!())
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true})
           |> json_response(201)

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/not-a-uuid/applications", %{consent: true})
           |> json_response(404)

    draft = job!(c.org, c.employer, %{"status" => "draft"})

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{draft.id}/applications", %{consent: true})
           |> json_response(404)
  end

  test "empty cover letters work and invalid or oversized cover letters do not insert", c do
    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true, cover_letter: nil})
           |> json_response(422)

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{
             consent: true,
             cover_letter: String.duplicate("x", 4001)
           })
           |> json_response(422)

    assert apply!(c, %{"cover_letter" => ""})["cover_letter"] == ""
  end

  test "employer moves through all stages with public history and a scheduled interview", c do
    application = apply!(c)
    time = DateTime.add(DateTime.utc_now(), 86_400, :second) |> DateTime.to_iso8601()

    final =
      Enum.reduce(~w(reviewing interview offer hired), application, fn stage, previous ->
        c.conn
        |> auth(c.employer)
        |> patch(~p"/api/applications/#{application["id"]}", %{
          status: stage,
          expected_status: previous["status"],
          note: "Next: #{stage}",
          interview_at: time
        })
        |> json_response(200)
        |> Map.fetch!("data")
      end)

    assert final["status"] == "hired"

    assert Enum.map(final["history"], & &1["status"]) ==
             ~w(applied reviewing interview offer hired)

    assert Enum.find(final["history"], &(&1["status"] == "interview"))["scheduled_at"] == time
    refute final["can_chat"]
    assert final["next_statuses"] == []

    listing =
      c.conn
      |> auth(c.employer)
      |> get(~p"/api/applications", %{scope: "hiring", status: "hired", job_id: c.job.id})
      |> json_response(200)

    assert [%{"id" => id}] = listing["data"]
    assert id == application["id"]
    assert listing["counts"]["hired"] == 1
    own = c.conn |> auth(c.candidate) |> get(~p"/api/applications") |> json_response(200)
    assert own["meta"]["total"] == 1
  end

  test "stage skipping, candidate promotion, stale writes and terminal reopening are rejected",
       c do
    app = apply!(c)

    assert c.conn
           |> auth(c.employer)
           |> patch(~p"/api/applications/#{app["id"]}", %{
             status: "offer",
             expected_status: "applied"
           })
           |> json_response(409)

    assert c.conn
           |> auth(c.candidate)
           |> patch(~p"/api/applications/#{app["id"]}", %{
             status: "hired",
             expected_status: "applied"
           })
           |> json_response(409)

    assert {:ok, record} =
             Applications.advance(c.employer, app["id"], %{
               "status" => "reviewing",
               "expected_status" => "applied"
             })

    assert {:error, :stale_application} =
             Applications.advance(c.employer, record.id, %{
               "status" => "interview",
               "expected_status" => "applied"
             })

    assert {:ok, _} =
             Applications.advance(c.candidate, record.id, %{
               "status" => "withdrawn",
               "expected_status" => "reviewing"
             })

    assert {:error, :invalid_transition} =
             Applications.advance(c.employer, record.id, %{
               "status" => "reviewing",
               "expected_status" => "withdrawn"
             })

    {:ok, final} = Applications.get(c.candidate, record.id)
    assert length(Applications.detail(final, c.candidate).history) == 3
  end

  test "applicants in other organizations and revoked hiring members cannot see submitted profiles",
       c do
    app = apply!(c)
    stranger = user!()
    org = organization!(stranger)
    grant!(stranger, org, "employer")

    assert c.conn
           |> auth(stranger)
           |> get(~p"/api/applications/#{app["id"]}")
           |> json_response(404)

    assert c.conn
           |> auth(stranger)
           |> get(~p"/api/applications", %{scope: "hiring"})
           |> json_response(200)
           |> Map.fetch!("data") == []

    c.membership
    |> Ash.Changeset.for_update(:update, %{status: :suspended})
    |> Ash.update!(authorize?: false)

    assert c.conn
           |> auth(c.employer)
           |> get(~p"/api/applications/#{app["id"]}")
           |> json_response(404)

    assert c.conn
           |> auth(c.candidate)
           |> get(~p"/api/applications/#{app["id"]}")
           |> json_response(200)
  end

  test "interview times accept browser seconds, milliseconds and microseconds", c do
    for precision <- [:second, :millisecond, :microsecond] do
      job = job!(c.org, c.employer)
      {:ok, app} = Applications.submit(c.candidate, job.id, %{"consent" => true})

      {:ok, _} =
        Applications.advance(c.employer, app.id, %{
          "status" => "reviewing",
          "expected_status" => "applied"
        })

      time = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(precision)

      body =
        c.conn
        |> auth(c.employer)
        |> patch(~p"/api/applications/#{app.id}", %{
          status: "interview",
          expected_status: "reviewing",
          interview_at: DateTime.to_iso8601(time)
        })
        |> json_response(200)

      {:ok, saved, _} = DateTime.from_iso8601(body["data"]["interview_at"])
      assert DateTime.compare(saved, time) == :eq
      assert elem(saved.microsecond, 1) == 6
    end
  end

  test "list pagination and filters reject invalid inputs and preserve listings with applications",
       c do
    apply!(c)

    for params <- [%{scope: "other"}, %{page: "0"}, %{status: "invented"}, %{job_id: "invalid"}] do
      assert c.conn
             |> auth(c.candidate)
             |> get(~p"/api/applications", params)
             |> json_response(400)
    end

    assert c.conn |> auth(c.employer) |> delete(~p"/api/jobs/#{c.job.id}") |> json_response(409)
  end
end
