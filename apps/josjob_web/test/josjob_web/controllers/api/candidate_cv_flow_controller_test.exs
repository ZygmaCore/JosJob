defmodule JosjobWeb.Api.CandidateCvFlowControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias JosjobJob.CurriculumVitae
  alias JosjobLrn.Learning.{Section, Course, Class, Enrollment}

  setup do
    employer = user!()
    candidate = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    %{candidate: candidate, employer: employer, org: org, job: job!(org, employer)}
  end

  test "reviewed matching facts become the shared CV and manual corrections update future matching only",
       c do
    cv = %{
      "cv_id" => "cv-flow",
      "skills" => ["Elixir"],
      "experience" => [
        %{"company" => "Example", "title" => "Developer", "start_date" => "2024-01"}
      ],
      "education" => [
        %{"institution" => "Example College", "degree" => "Bachelor", "field" => "Computing"}
      ]
    }

    result =
      c.conn
      |> auth(c.candidate)
      |> post(~p"/api/rag/analyses", %{"cv" => cv})
      |> json_response(200)

    assert result["data"]["persisted"]
    profile = CurriculumVitae.get_for(c.candidate)
    assert profile.skills == ["Elixir"]

    assert [%{"name" => "Example", "position" => "Developer"}] =
             Enum.map(profile.experience, &Map.take(&1, ~w(name position)))

    assert [%{"name" => "Example College", "major" => "Computing"}] =
             Enum.map(profile.education, &Map.take(&1, ~w(name major)))

    corrected =
      c.conn
      |> auth(c.candidate)
      |> patch(~p"/api/me/cv", %{"skills" => ["Elixir", " SQL ", "sql"]})
      |> json_response(200)

    assert corrected["data"]["skills"] == ["Elixir", "SQL"]

    page =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/jobs", %{sort: "relevance"})
      |> json_response(200)

    assert Enum.find(page["data"], &(&1["id"] == c.job.id))["relevance"]["missing_skills"] == []

    suggestions =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/jobs/#{c.job.id}/application-suggestions")
      |> json_response(200)

    assert suggestions["data"]["status"] == "matched"

    submitted =
      c.conn
      |> auth(c.candidate)
      |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true, cover_letter: ""})
      |> json_response(201)

    assert submitted["data"]["profile"]["skills"] == ["Elixir", "SQL"]
    {:ok, _} = CurriculumVitae.save_for(c.candidate, %{"skills" => ["Changed later"]})

    stored =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/applications/#{submitted["data"]["id"]}")
      |> json_response(200)

    assert stored["data"]["profile"]["skills"] == ["Elixir", "SQL"]
    mine = c.conn |> auth(c.candidate) |> get(~p"/api/jobs/#{c.job.id}") |> json_response(200)
    assert mine["data"]["my_application"]["id"] == submitted["data"]["id"]
    other = c.conn |> auth(user!()) |> get(~p"/api/jobs/#{c.job.id}") |> json_response(200)
    assert other["data"]["my_application"] == nil
  end

  test "extraction review keeps owner checks and saves the user's corrected skills", c do
    previous = Application.get_env(:josjob_rag, :pdf_service)

    Application.put_env(:josjob_rag, :pdf_service,
      http_client: fn _ ->
        {:ok,
         %{
           status: 200,
           body: %{
             "data" => %{
               "user_id" => c.candidate.id,
               "cv_id" => "reviewed-pdf",
               "status" => "done",
               "result" => %{"skills" => ["Elixir"], "experience" => [], "education" => []}
             }
           }
         }}
      end
    )

    on_exit(fn -> Application.put_env(:josjob_rag, :pdf_service, previous) end)
    body = %{extraction_id: "job-review", reviewed_skills: ["Elixir", "SQL"]}
    assert c.conn |> auth(user!()) |> post(~p"/api/rag/analyses", body) |> json_response(404)

    response =
      c.conn |> auth(c.candidate) |> post(~p"/api/rag/analyses", body) |> json_response(200)

    assert response["data"]["persisted"]
    assert CurriculumVitae.get_for(c.candidate).skills == ["Elixir", "SQL"]
  end

  test "skill editing validates shape and length and cannot forge internal CV facts", c do
    for skills <- [%{}, [42], [String.duplicate("x", 101)], List.duplicate("SQL", 101)] do
      assert c.conn
             |> auth(c.candidate)
             |> patch(~p"/api/me/cv", %{skills: skills})
             |> json_response(422)
    end

    assert c.conn
           |> auth(c.candidate)
           |> patch(~p"/api/me/cv", %{cv_facts: %{skills: ["Forged"]}, user_id: c.employer.id})
           |> json_response(200)

    assert CurriculumVitae.get_for(c.candidate).skills == []
    assert CurriculumVitae.get_for(c.employer).skills == []
  end

  test "paid course material URLs are exposed only after enrollment or to its instructor", c do
    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Flow material test"})
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(:create, %{
        title: "SQL",
        section_id: section.id,
        is_public: true,
        price_cents: 2500
      })
      |> Ash.create!(authorize?: false)

    class =
      Class
      |> Ash.Changeset.for_create(:create, %{
        course_id: course.id,
        organization_id: c.org.id,
        instructor_id: c.employer.id
      })
      |> Ash.create!(authorize?: false)

    document =
      JosjobDoc.Documents.Document
      |> Ash.Changeset.for_create(:create, %{
        title: "Lesson one",
        url: "https://example.com/lesson.pdf",
        user_id: c.employer.id,
        organization_id: c.org.id,
        course_id: course.id
      })
      |> Ash.create!(authorize?: false)

    before =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/catalog/courses/#{course.id}")
      |> json_response(200)

    assert before["data"]["materials"] == []
    assert hd(before["data"]["classes"])["materials"] == []

    enrollment =
      Enrollment
      |> Ash.Changeset.for_create(:create, %{class_id: class.id, student_id: c.candidate.id})
      |> Ash.create!(authorize?: false)

    after_enrollment =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/catalog/courses/#{course.id}")
      |> json_response(200)

    assert Enum.any?(after_enrollment["data"]["materials"], &(&1["id"] == document.id))

    stranger =
      c.conn |> auth(user!()) |> get(~p"/api/catalog/courses/#{course.id}") |> json_response(200)

    assert stranger["data"]["materials"] == []
    Ash.destroy!(enrollment, authorize?: false)

    left =
      c.conn
      |> auth(c.candidate)
      |> get(~p"/api/catalog/courses/#{course.id}")
      |> json_response(200)

    assert left["data"]["materials"] == []
  end
end
