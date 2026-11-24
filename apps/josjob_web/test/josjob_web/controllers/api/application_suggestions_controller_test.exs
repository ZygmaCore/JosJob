defmodule JosjobWeb.Api.ApplicationSuggestionsControllerTest do
  use JosjobWeb.ConnCase, async: false

  import JosjobWeb.JobFixtures
  alias Josjob.Accounts.Profile
  alias JosjobLrn.Learning.{Class, Course, CourseOrganization, Section}
  alias JosjobRag.{Analyses, Analyzer}

  setup do
    employer = user!()
    candidate = user!()
    org = organization!(employer)
    grant!(employer, org, "employer")
    job = job!(org, employer)
    %{employer: employer, candidate: candidate, org: org, job: job}
  end

  defp skills!(user, skills) do
    Profile
    |> Ash.Changeset.for_create(:upsert_answers, %{
      user_id: user.id,
      answers: %{"skills" => skills}
    })
    |> Ash.create!(authorize?: false)
  end

  defp course!(context, attrs) do
    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Application learning"})
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(%{title: "SQL essentials", section_id: section.id, is_public: true}, attrs)
      )
      |> Ash.create!(authorize?: false)

    class =
      Class
      |> Ash.Changeset.for_create(:create, %{
        title: "SQL class",
        course_id: course.id,
        organization_id: context.org.id,
        instructor_id: context.employer.id
      })
      |> Ash.create!(authorize?: false)

    {course, class}
  end

  defp suggestions(context, user \\ nil) do
    context.conn
    |> auth(user || context.candidate)
    |> get(~p"/api/jobs/#{context.job.id}/application-suggestions")
    |> json_response(200)
    |> Map.fetch!("data")
  end

  test "requires login and rejects missing, draft and closed listings", c do
    assert c.conn
           |> get(~p"/api/jobs/#{c.job.id}/application-suggestions")
           |> json_response(401)

    assert c.conn
           |> auth(c.candidate)
           |> get(~p"/api/jobs/#{Ecto.UUID.generate()}/application-suggestions")
           |> json_response(404)

    draft = job!(c.org, c.employer, %{"status" => "draft"})

    assert c.conn
           |> auth(c.candidate)
           |> get(~p"/api/jobs/#{draft.id}/application-suggestions")
           |> json_response(404)

    closed = job!(c.org, c.employer, %{"status" => "expired"})

    assert c.conn
           |> auth(c.employer)
           |> get(~p"/api/jobs/#{closed.id}/application-suggestions")
           |> json_response(409)
  end

  test "suggests a real public course without requiring organization membership or changing applications",
       c do
    skills!(c.candidate, ["elixir"])
    {course, class} = course!(c, %{price_cents: 2500, currency: "usd"})
    data = suggestions(c)

    assert data["status"] == "gap"
    assert data["source"] == "saved_profile"
    assert data["matched_skills"] == ["Elixir"]
    assert data["missing_skills"] == ["SQL"]
    assert data["uncovered_skills"] == []
    assert [recommended] = data["courses"]
    assert recommended["id"] == course.id
    assert recommended["class_id"] == class.id
    assert recommended["class_count"] == 1
    assert recommended["matched_skills"] == ["SQL"]
    assert recommended["price_cents"] == 2500
    assert Josjob.Repo.aggregate(JosjobJob.Application, :count) == 0

    assert c.conn
           |> auth(c.candidate)
           |> post(~p"/api/jobs/#{c.job.id}/applications", %{consent: true, cover_letter: ""})
           |> json_response(201)
  end

  test "never recommends inactive or inaccessible courses", c do
    skills!(c.candidate, ["Elixir"])
    course!(c, %{is_public: false})
    course!(c, %{is_active: false})

    data = suggestions(c)
    assert data["missing_skills"] == ["SQL"]
    assert data["courses"] == []
    assert data["uncovered_skills"] == ["SQL"]
  end

  test "shared private courses expose only classes in the candidate's active organizations", c do
    skills!(c.candidate, ["Elixir"])
    {course, _hidden_class} = course!(c, %{is_public: false})
    candidate_org = organization!(c.candidate)
    grant!(c.candidate, candidate_org, "graduate")

    CourseOrganization
    |> Ash.Changeset.for_create(:create, %{
      course_id: course.id,
      organization_id: candidate_org.id
    })
    |> Ash.create!(authorize?: false)

    assert [%{"class_id" => nil, "class_count" => 0}] = suggestions(c)["courses"]

    visible_class =
      Class
      |> Ash.Changeset.for_create(:create, %{
        course_id: course.id,
        organization_id: candidate_org.id,
        instructor_id: c.employer.id
      })
      |> Ash.create!(authorize?: false)

    assert [recommended] = suggestions(c)["courses"]
    assert recommended["class_id"] == visible_class.id
    assert recommended["class_count"] == 1
  end

  test "uses only the candidate's saved analyzed CV and compares skills even across role categories",
       c do
    skills!(c.candidate, ["Elixir", "SQL"])
    cv = %{"cv_id" => "candidate-cv", "skills" => ["Accounting"]}
    {:ok, result} = Analyzer.analyze(c.candidate, cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(c.candidate, cv, result)
    other = user!()
    other_cv = %{"cv_id" => "other-cv", "skills" => ["Elixir", "SQL"]}
    {:ok, other_result} = Analyzer.analyze(other, other_cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(other, other_cv, other_result)

    data = suggestions(c)
    assert data["source"] == "analyzed_cv"
    assert data["missing_skills"] == ["Elixir", "SQL"]
  end

  test "all matched skills, absent CV skills and absent requirements have honest states", c do
    assert suggestions(c)["status"] == "cv_required"
    assert suggestions(c)["missing_skills"] == []

    skills!(c.candidate, ["ELIXIR", "sql"])
    data = suggestions(c)
    assert data["status"] == "matched"
    assert data["missing_skills"] == []
    assert data["courses"] == []

    job = job!(c.org, c.employer, %{"requirements" => []})
    assert suggestions(%{c | job: job})["status"] == "no_requirements"
  end

  test "an analysis without extracted skills still allows saved CV-profile skills", c do
    cv = %{
      "cv_id" => "experience-only",
      "skills" => [],
      "experience" => [%{"title" => "Developer"}]
    }

    {:ok, result} = Analyzer.analyze(c.candidate, cv, jobs: [], courses: [])
    {:ok, _} = Analyses.save(c.candidate, cv, result)
    assert suggestions(c)["status"] == "cv_required"

    skills!(c.candidate, ["Elixir", "SQL"])
    data = suggestions(c)
    assert data["source"] == "saved_profile"
    assert data["status"] == "matched"
  end

  test "skill aliases match without conflating distinct skills", c do
    skills!(c.candidate, ["JS", "Postgres 15", "JavaScript"])
    job = job!(c.org, c.employer, %{"requirements" => ["JavaScript", "PostgreSQL", "Java"]})
    data = suggestions(%{c | job: job})
    assert data["matched_skills"] == ["JavaScript", "PostgreSQL"]
    assert data["missing_skills"] == ["Java"]
  end
end
