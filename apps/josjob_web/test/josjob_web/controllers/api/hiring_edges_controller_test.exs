defmodule JosjobWeb.Api.HiringEdgesControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias JosjobJob.{Applications, CurriculumVitae}
  alias JosjobDoc.Documents.Document

  setup do
    employer = user!()
    candidate = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    grant!(candidate, org, "graduate")
    %{employer: employer, candidate: candidate, org: org}
  end

  defp application_at(c, status) do
    job = job!(c.org, c.employer)
    {:ok, app} = Applications.submit(c.candidate, job.id, %{"consent" => true})
    stages = ~w(applied reviewing interview offer hired)
    preceding = Enum.take_while(stages, &(&1 != status))

    Enum.reduce(
      Enum.drop(preceding, 1) ++ if(status == "applied", do: [], else: [status]),
      app,
      fn target, current ->
        {:ok, next} =
          Applications.advance(c.employer, current.id, %{
            "status" => target,
            "expected_status" => current.status
          })

        next
      end
    )
  end

  test "each active stage permits rejection and withdrawal, and each terminal stage stays closed",
       c do
    for current <- ~w(applied reviewing interview offer), target <- ~w(rejected withdrawn) do
      app = application_at(c, current)
      actor = if target == "withdrawn", do: c.candidate, else: c.employer

      response =
        c.conn
        |> auth(actor)
        |> patch(~p"/api/applications/#{app.id}", %{
          status: target,
          expected_status: current,
          note: "Shared exit reason"
        })
        |> json_response(200)

      assert response["data"]["status"] == target
      assert List.last(response["data"]["history"])["note"] == "Shared exit reason"

      for user <- [c.candidate, c.employer] do
        for next <- ~w(applied reviewing interview offer hired rejected withdrawn) do
          assert c.conn
                 |> auth(user)
                 |> patch(~p"/api/applications/#{app.id}", %{
                   status: next,
                   expected_status: target
                 })
                 |> json_response(409)
        end
      end

      assert {:ok, history} = JosjobRt.Chat.list(actor, "application", app.id, %{})
      refute history.thread.can_send
    end
  end

  test "only the next hiring stage is allowed and candidates cannot promote or reject themselves",
       c do
    stages = ~w(applied reviewing interview offer hired)

    for {current, index} <- Enum.with_index(stages) do
      app = application_at(c, current)
      allowed = Enum.at(stages, index + 1)

      for target <- stages, target != allowed do
        assert c.conn
               |> auth(c.employer)
               |> patch(~p"/api/applications/#{app.id}", %{
                 status: target,
                 expected_status: current
               })
               |> json_response(409)
      end

      for target <- stages ++ ["rejected"] do
        assert c.conn
               |> auth(c.candidate)
               |> patch(~p"/api/applications/#{app.id}", %{
                 status: target,
                 expected_status: current
               })
               |> json_response(409)
      end

      {:ok, stored} = Applications.get(c.candidate, app.id)
      assert stored.status == current
      assert length(Applications.detail(stored, c.candidate).history) == index + 1
    end
  end

  test "listing expiration blocks new submissions and keeps existing hiring and chat available",
       c do
    app = application_at(c, "applied")

    assert c.conn
           |> auth(c.employer)
           |> patch(~p"/api/jobs/#{app.job_id}", %{status: "expired"})
           |> json_response(200)

    assert c.conn |> auth(c.candidate) |> get(~p"/api/jobs/#{app.job_id}") |> json_response(404)

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{app.job_id}/applications", %{consent: true})
           |> json_response(404)

    assert c.conn |> auth(c.employer) |> delete(~p"/api/jobs/#{app.job_id}") |> json_response(409)

    assert c.conn
           |> auth(c.candidate)
           |> get(~p"/api/applications/#{app.id}")
           |> json_response(200)

    assert {:ok, _} =
             Applications.advance(c.employer, app.id, %{
               "status" => "reviewing",
               "expected_status" => "applied"
             })

    assert {:ok, _} =
             JosjobRt.Chat.send_message(c.candidate, "application", app.id, %{
               "body" => "Following up",
               "client_id" => "expired-listing"
             })
  end

  test "invalid interview dates and public notes do not advance the stage or append history", c do
    app = application_at(c, "reviewing")

    for value <- ["not-a-date", "2020-01-01T00:00:00Z", [], 123] do
      assert c.conn
             |> auth(c.employer)
             |> patch(~p"/api/applications/#{app.id}", %{
               status: "interview",
               expected_status: "reviewing",
               interview_at: value
             })
             |> json_response(422)
    end

    for note <- [[], 123, String.duplicate("n", 2001)] do
      assert c.conn
             |> auth(c.employer)
             |> patch(~p"/api/applications/#{app.id}", %{
               status: "interview",
               expected_status: "reviewing",
               note: note
             })
             |> json_response(422)
    end

    assert c.conn
           |> auth(c.employer)
           |> patch(~p"/api/applications/#{app.id}", %{status: "interview"})
           |> json_response(409)

    {:ok, stored} = Applications.get(c.candidate, app.id)
    assert stored.status == "reviewing"
    assert length(Applications.detail(stored, c.candidate).history) == 2
  end

  test "application lists paginate without overlap, filter by job, and return unfiltered stage counts",
       c do
    applications = for _ <- 1..26, do: application_at(c, "applied")
    first = hd(applications)

    {:ok, _} =
      Applications.advance(c.employer, first.id, %{
        "status" => "reviewing",
        "expected_status" => "applied"
      })

    for {user, scope} <- [{c.candidate, "mine"}, {c.employer, "hiring"}] do
      page1 =
        c.conn |> auth(user) |> get(~p"/api/applications", %{scope: scope}) |> json_response(200)

      page2 =
        c.conn
        |> auth(user)
        |> get(~p"/api/applications", %{scope: scope, page: "2"})
        |> json_response(200)

      assert length(page1["data"]) == 25
      assert length(page2["data"]) == 1
      assert page1["meta"]["total"] == 26
      assert page1["meta"]["total_pages"] == 2
      assert length(Enum.uniq_by(page1["data"] ++ page2["data"], & &1["id"])) == 26

      filtered =
        c.conn
        |> auth(user)
        |> get(~p"/api/applications", %{scope: scope, status: "reviewing"})
        |> json_response(200)

      assert [%{"id" => id}] = filtered["data"]
      assert id == first.id
      assert filtered["counts"] == %{"applied" => 25, "reviewing" => 1}

      by_job =
        c.conn
        |> auth(user)
        |> get(~p"/api/applications", %{scope: scope, job_id: first.job_id})
        |> json_response(200)

      assert by_job["meta"]["total"] == 1
      assert by_job["counts"] == %{"reviewing" => 1}
    end
  end

  test "submission shares only the explicitly selected owned PDF and preserves it after profile changes",
       c do
    document = fn owner, title ->
      Document
      |> Ash.Changeset.for_create(:create, %{
        title: title,
        url: "https://example.invalid/#{Ecto.UUID.generate()}.pdf",
        mime_type: "application/pdf",
        user_id: owner.id,
        organization_id: c.org.id
      })
      |> Ash.create!(authorize?: false)
    end

    selected = document.(c.candidate, "Selected resume")
    other = document.(c.candidate, "Unselected private document")
    foreign = document.(c.employer, "Employer private document")

    assert {:error, :invalid_resume_document} =
             CurriculumVitae.save_for(c.candidate, %{"resume_document_id" => foreign.id})

    {:ok, _} = CurriculumVitae.save_for(c.candidate, %{"resume_document_id" => selected.id})
    app = application_at(c, "applied")
    {:ok, _} = CurriculumVitae.save_for(c.candidate, %{"resume_document_id" => other.id})

    detail =
      c.conn |> auth(c.employer) |> get(~p"/api/applications/#{app.id}") |> json_response(200)

    assert detail["data"]["profile"]["resume_document"]["id"] == selected.id
    refute Map.has_key?(detail["data"]["profile"], "pdf_documents")
    refute inspect(detail["data"]["profile"]) =~ other.url
    refute inspect(detail["data"]["profile"]) =~ foreign.url
  end
end
