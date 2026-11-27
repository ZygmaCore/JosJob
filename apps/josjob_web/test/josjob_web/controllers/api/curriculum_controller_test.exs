defmodule JosjobWeb.Api.CurriculumControllerTest do
  use JosjobWeb.ConnCase, async: false
  import JosjobWeb.JobFixtures
  alias Josjob.Repo
  alias JosjobLrn.Learning.{Class, Course, CourseLesson, Enrollment, Section}

  setup do
    owner = user!()
    user = user!()
    org = organization!(owner)

    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Study"})
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(:create, %{
        title: "SQL practice",
        section_id: section.id,
        is_public: true,
        skill_tags: ["SQL"]
      })
      |> Ash.create!(authorize?: false)

    lessons =
      for position <- 1..3 do
        Repo.insert!(%CourseLesson{
          course_id: course.id,
          module_title: "Basics",
          title: "Lesson #{position}",
          position: position,
          kind: if(position == 3, do: "quiz", else: "reading"),
          body: "Original SQL learning material.",
          questions:
            if(position == 3,
              do: [
                %{
                  "id" => "q",
                  "prompt" => "Which query reads rows?",
                  "options" => ["SELECT", "DELETE"],
                  "correct_index" => 0
                }
              ],
              else: []
            )
        })
      end

    %{owner: owner, user: user, org: org, course: course, lessons: lessons}
  end

  defp get_study(c, user),
    do:
      c.conn
      |> auth(user)
      |> get(~p"/api/catalog/courses/#{c.course.id}/study")
      |> json_response(200)
      |> Map.fetch!("data")

  defp complete(c, lesson, answers \\ %{}),
    do:
      c.conn
      |> auth(c.user)
      |> post(~p"/api/catalog/courses/#{c.course.id}/study/lessons/#{lesson.id}/complete", %{
        answers: answers
      })

  test "private progress, ordered reading and server grading survive reloads without exposing answers",
       c do
    [first, second, quiz] = c.lessons
    assert c.conn |> get(~p"/api/catalog/courses/#{c.course.id}/study") |> json_response(401)
    preview = get_study(c, c.user)
    assert preview["enrolled"] == false
    assert Enum.all?(preview["lessons"], &is_nil(&1["body"]))
    assert complete(c, first) |> json_response(403)

    assert c.conn
           |> auth(c.user)
           |> post(~p"/api/catalog/courses/#{c.course.id}/study/enroll")
           |> json_response(200)

    assert complete(c, quiz, %{"q" => 0}) |> json_response(409)
    assert complete(c, first) |> json_response(200)
    assert get_study(c, c.user)["progress"] == 33
    assert get_study(c, c.owner)["progress"] == 0
    assert complete(c, second) |> json_response(200)
    unlocked = get_study(c, c.user)
    quiz_data = List.last(unlocked["lessons"])
    assert [%{"id" => "q", "options" => ["SELECT", "DELETE"]} = question] = quiz_data["questions"]
    refute Map.has_key?(question, "correct_index")
    failed = complete(c, quiz, %{"q" => 1}) |> json_response(200)
    assert failed["data"]["assessment"] == %{"passed" => false, "score" => 0}
    assert failed["data"]["progress"] == 67
    assert complete(c, quiz, %{"q" => 0}) |> json_response(200)
    assert get_study(c, c.user)["progress"] == 100
    assert complete(c, first) |> json_response(200)
    assert get_study(c, c.user)["completed_count"] == 3
    mine = c.conn |> auth(c.user) |> get(~p"/api/me/course-studies") |> json_response(200)
    assert [%{"progress" => 100}] = mine["data"]
    overview = c.conn |> auth(c.user) |> get(~p"/api/me/learning-overview") |> json_response(200)
    assert overview["data"]["stats"]["completed_enrollments"] == 1
  end

  test "visibility, ownership and payment checks apply to course content", c do
    c.course
    |> Ash.Changeset.for_update(:update, %{price_cents: 1500})
    |> Ash.update!(authorize?: false)

    assert c.conn
           |> auth(c.user)
           |> post(~p"/api/catalog/courses/#{c.course.id}/study/enroll")
           |> json_response(402)

    class =
      Class
      |> Ash.Changeset.for_create(:create, %{
        course_id: c.course.id,
        organization_id: c.org.id,
        instructor_id: c.owner.id
      })
      |> Ash.create!(authorize?: false)

    enrollment =
      Enrollment
      |> Ash.Changeset.for_create(:create, %{class_id: class.id, student_id: c.user.id})
      |> Ash.create!(authorize?: false)

    assert c.conn
           |> auth(c.user)
           |> post(~p"/api/catalog/courses/#{c.course.id}/study/enroll")
           |> json_response(200)

    Ash.destroy!(enrollment, authorize?: false)

    assert c.conn
           |> auth(c.user)
           |> get(~p"/api/catalog/courses/#{c.course.id}/study")
           |> json_response(402)

    assert complete(c, hd(c.lessons)) |> json_response(402)

    c.course
    |> Ash.Changeset.for_update(:update, %{is_public: false})
    |> Ash.update!(authorize?: false)

    assert c.conn
           |> auth(c.user)
           |> get(~p"/api/catalog/courses/#{c.course.id}/study")
           |> json_response(404)

    assert c.conn
           |> auth(c.user)
           |> get("/api/catalog/courses/not-a-uuid/study")
           |> json_response(404)
  end
end
