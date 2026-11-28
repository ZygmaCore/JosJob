defmodule JosjobWeb.Api.CourseAwardControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias Josjob.Repo
  alias JosjobJob.{CourseAward, CurriculumVitae}
  alias JosjobLrn.Curriculum
  alias JosjobLrn.Learning.{Course, CourseLesson, Section}

  defp course! do
    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Award courses"})
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(:create, %{
        title: "SQL foundations",
        section_id: section.id,
        is_public: true,
        skill_tags: ["SQL", "Docker"]
      })
      |> Ash.create!(authorize?: false)

    reading =
      Repo.insert!(%CourseLesson{
        course_id: course.id,
        module_title: "Learn",
        title: "Read",
        position: 1,
        kind: "reading",
        body: "SQL reading material"
      })

    quiz =
      Repo.insert!(%CourseLesson{
        course_id: course.id,
        module_title: "Check",
        title: "Quiz",
        position: 2,
        kind: "quiz",
        questions: [
          %{
            "id" => "q",
            "prompt" => "Read rows?",
            "options" => ["SELECT", "DELETE"],
            "correct_index" => 0
          }
        ]
      })

    {course, reading, quiz}
  end

  defp finish(user, course, reading, quiz) do
    assert {:ok, _} = Curriculum.enroll(user, course.id)
    assert {:ok, _} = Curriculum.complete(user, course.id, reading.id, %{})
    assert {:ok, result} = Curriculum.complete(user, course.id, quiz.id, %{"q" => 0})
    result.award
  end

  test "skills are granted once after passing and participate in CV, job suggestions and saved CV matching",
       c do
    user = user!()
    employer = user!()
    org = organization!(employer)
    job = job!(org, employer)
    cv = %{"cv_id" => "award-cv", "skills" => ["Elixir"]}
    {:ok, result} = JosjobRag.Analyzer.analyze(user, cv, jobs: [], courses: [])
    {:ok, _} = JosjobRag.CandidateProfile.save(user, cv, result)
    {course, reading, quiz} = course!()
    {:ok, _} = Curriculum.enroll(user, course.id)
    {:ok, _} = Curriculum.complete(user, course.id, reading.id, %{})
    {:ok, failed} = Curriculum.complete(user, course.id, quiz.id, %{"q" => 1})
    assert failed.award == nil
    assert CurriculumVitae.get_for(user).earned_skill_tags == []
    {:ok, done} = Curriculum.complete(user, course.id, quiz.id, %{"q" => 0})
    assert done.award.name_locked == false
    assert done.award.recipient_name == nil
    assert CurriculumVitae.get_for(user).earned_skill_tags == ["SQL", "Docker"]
    assert {:ok, matched_cv} = JosjobRag.CandidateProfile.cv(user)
    assert matched_cv["skills"] == ["Elixir", "SQL", "Docker"]
    assert {:ok, suggestions} = JosjobRag.ApplicationSuggestions.get(user, job.id)
    assert suggestions.missing_skills == []
    assert {:ok, _} = CurriculumVitae.save_for(user, %{"skills" => []})
    assert CurriculumVitae.get_for(user).skills == ["SQL", "Docker"]
    assert {:ok, repeated} = Curriculum.complete(user, course.id, quiz.id, %{"q" => 0})
    assert repeated.award.id == done.award.id
    assert Repo.aggregate(CourseAward, :count) == 1

    course
    |> Ash.Changeset.for_update(:update, %{skill_tags: ["Other"]})
    |> Ash.update!(authorize?: false)

    {:ok, _} = Curriculum.complete(user, course.id, reading.id, %{})
    assert CurriculumVitae.get_for(user).earned_skill_tags == ["SQL", "Docker"]
    assert c.conn |> auth(user) |> get(~p"/api/me/cv") |> json_response(200)
  end

  test "CV confirmation is explicit and fresh, certificate names lock per certificate across CV edits and direct DB writes",
       c do
    user = user!()
    other = user!()
    {course, reading, quiz} = course!()
    award = finish(user, course, reading, quiz)
    assert {:ok, _} = CurriculumVitae.save_for(user, %{"full_name" => "  Ari  Pratama  "})

    preview =
      c.conn |> auth(user) |> get(~p"/api/me/course-awards/#{award.id}") |> json_response(200)

    assert preview["data"]["cv_name"] == "Ari Pratama"

    assert c.conn
           |> auth(other)
           |> get(~p"/api/me/course-awards/#{award.id}")
           |> json_response(404)

    assert c.conn
           |> auth(user)
           |> post(~p"/api/me/course-awards/#{award.id}/confirm", %{expected_name: "Ari Pratama"})
           |> json_response(422)

    assert {:ok, _} = CurriculumVitae.save_for(user, %{"full_name" => "Ari Wijaya"})

    assert c.conn
           |> auth(user)
           |> post(~p"/api/me/course-awards/#{award.id}/confirm", %{
             confirm_cv: true,
             expected_name: "Ari Pratama"
           })
           |> json_response(409)

    issued =
      c.conn
      |> auth(user)
      |> post(~p"/api/me/course-awards/#{award.id}/confirm", %{
        confirm_cv: true,
        expected_name: "Ari Wijaya",
        recipient_name: "Injected name"
      })
      |> json_response(200)

    assert issued["data"]["recipient_name"] == "Ari Wijaya"
    assert issued["data"]["name_locked"] == true
    assert {:ok, _} = CurriculumVitae.save_for(user, %{"full_name" => "Ari New Name"})

    repeated =
      c.conn
      |> auth(user)
      |> post(~p"/api/me/course-awards/#{award.id}/confirm", %{
        confirm_cv: true,
        expected_name: "Ari New Name"
      })
      |> json_response(200)

    assert repeated["data"] == issued["data"]

    assert c.conn
           |> auth(user)
           |> patch(~p"/api/me/certificates/#{award.id}", %{recipient_name: "Changed"})
           |> json_response(409)

    assert c.conn
           |> auth(user)
           |> delete(~p"/api/me/certificates/#{award.id}")
           |> json_response(409)

    {second, r, q} = course!()
    second_award = finish(user, second, r, q)

    assert {:ok, new_certificate} =
             JosjobLrn.CourseAwards.confirm(user, second_award.id, %{
               "confirm_cv" => true,
               "expected_name" => "Ari New Name"
             })

    assert new_certificate.recipient_name == "Ari New Name"
    certificates = c.conn |> auth(user) |> get(~p"/api/me/certificates") |> json_response(200)
    assert length(certificates["data"]) == 2

    assert_raise Postgrex.Error, fn ->
      Repo.query!("UPDATE course_awards SET recipient_name = 'Changed' WHERE id::text = $1", [
        award.id
      ])
    end
  end
end
