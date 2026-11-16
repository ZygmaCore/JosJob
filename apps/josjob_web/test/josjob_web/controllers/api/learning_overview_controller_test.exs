defmodule JosjobWeb.Api.LearningOverviewControllerTest do
  use JosjobWeb.ConnCase, async: false

  import JosjobWeb.JobFixtures, only: [auth: 2, grant!: 3]
  alias Josjob.Accounts.User
  alias Josjob.Orgs.{Membership, Organization}
  alias JosjobLrn.Learning.{Class, Course, CourseOrganization, Enrollment, Section}

  defp create!(resource, attrs) do
    resource |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!(authorize?: false)
  end

  defp user!(attrs \\ %{}) do
    create!(
      User,
      Map.merge(
        %{
          email: "overview#{System.unique_integer([:positive])}@example.com",
          full_name: "Learning tester"
        },
        attrs
      )
    )
  end

  defp course!(org, attrs \\ %{}) do
    section = create!(Section, %{name: "Category"})
    course = create!(Course, Map.merge(%{title: "Course", section_id: section.id}, attrs))
    create!(CourseOrganization, %{course_id: course.id, organization_id: org.id})
    course
  end

  defp class!(org, course, teacher, schedule \\ []) do
    create!(Class, %{
      title: "Class",
      organization_id: org.id,
      course_id: course.id,
      instructor_id: teacher.id,
      schedule: schedule
    })
  end

  defp enroll!(class, user, status \\ :active) do
    create!(Enrollment, %{class_id: class.id, student_id: user.id, status: status})
  end

  defp summary(conn, user, params \\ %{}) do
    conn
    |> auth(user)
    |> get(~p"/api/me/learning-overview", params)
    |> json_response(200)
    |> Map.fetch!("data")
  end

  setup do
    teacher = user!()
    learner = user!()
    org = create!(Organization, %{name: "Overview org", user_id: teacher.id})
    %{teacher: teacher, learner: learner, org: org}
  end

  test "requires authentication and validates scope", %{conn: conn, learner: learner} do
    assert conn |> get(~p"/api/me/learning-overview") |> json_response(401)

    assert conn
           |> auth(learner)
           |> get(~p"/api/me/learning-overview?scope=anything")
           |> json_response(400)
  end

  test "empty accounts have zero totals and no invented activity", %{conn: conn, learner: learner} do
    data = summary(conn, learner)
    assert data["scope"] == "learner"

    assert data["stats"] == %{
             "active_enrollments" => 0,
             "completed_enrollments" => 0,
             "available_courses" => 0,
             "upcoming_sessions" => 0
           }

    for key <- ~w(enrollments courses upcoming_sessions members completion),
        do: assert(data[key] == [])

    refute Map.has_key?(data, "weekly_hours")
    refute Map.has_key?(data, "certificates")
  end

  test "own enrollments, actual statuses and future schedules drive the learner snapshot", ctx do
    %{conn: conn, learner: learner, org: org, teacher: teacher} = ctx
    course = course!(org, %{is_public: true})
    tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
    past = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
    session = %{"date" => tomorrow, "start" => "10:00", "end" => "11:00"}

    class =
      class!(org, course, teacher, [session, session, %{"date" => past}, %{"date" => %{}}, %{}])

    enrollment = enroll!(class, learner)
    completed = class!(org, course, teacher, [session])
    enroll!(completed, learner, :completed)
    enroll!(class!(org, course, teacher), user!())
    data = summary(conn, learner, %{user_id: teacher.id})
    assert data["stats"]["active_enrollments"] == 1
    assert data["stats"]["completed_enrollments"] == 1
    assert data["stats"]["upcoming_sessions"] == 1

    assert [%{"id" => id, "class_id" => class_id, "course" => %{"id" => course_id}}] =
             data["enrollments"]

    assert {id, class_id, course_id} == {enrollment.id, class.id, course.id}
    assert [%{"date" => ^tomorrow, "instructor" => "Learning tester"}] = data["upcoming_sessions"]
    assert data["courses"] == []
  end

  test "catalog previews include public and active-member courses, never private or inactive ones",
       ctx do
    %{conn: conn, learner: learner, org: org} = ctx
    grant!(learner, org, "graduate")
    shared = course!(org, %{title: "Shared"})
    foreign_org = create!(Organization, %{name: "Other", user_id: learner.id})
    public = course!(foreign_org, %{title: "Public", is_public: true})
    course!(foreign_org, %{title: "Private"})
    course!(org, %{title: "Archived", is_public: true, is_active: false})
    data = summary(conn, learner)
    assert data["stats"]["available_courses"] == 2
    assert Enum.map(data["courses"], & &1["id"]) == [public.id, shared.id]
  end

  test "suspended memberships do not unlock private courses or organization summaries", ctx do
    %{conn: conn, learner: learner, org: org} = ctx
    membership = grant!(learner, org, "coordinator")

    membership
    |> Ash.Changeset.for_update(:update, %{status: :suspended})
    |> Ash.update!(authorize?: false)

    course!(org)
    assert summary(conn, learner)["courses"] == []

    assert conn
           |> auth(learner)
           |> get(~p"/api/me/learning-overview?scope=organization")
           |> json_response(403)
  end

  test "an ordinary member or employer cannot request the private organization learning roster",
       ctx do
    %{conn: conn, learner: learner, org: org} = ctx
    grant!(learner, org, "employer")

    assert conn
           |> auth(learner)
           |> get(~p"/api/me/learning-overview?scope=organization")
           |> json_response(403)
  end

  test "organization totals and previews stay in permitted tenants", ctx do
    %{conn: conn, learner: learner, org: org, teacher: coordinator} = ctx
    grant!(coordinator, org, "coordinator")
    grant!(learner, org, "graduate")
    course = course!(org)
    class = class!(org, course, coordinator)
    enroll!(class, learner, :completed)
    enroll!(class, coordinator)

    foreign = create!(Organization, %{name: "Foreign", user_id: coordinator.id})
    grant!(coordinator, foreign, "graduate")
    stranger = user!(%{full_name: "Hidden learner"})
    create!(Membership, %{user_id: stranger.id, organization_id: foreign.id})
    foreign_course = course!(foreign, %{title: "Hidden course"})
    enroll!(class!(foreign, foreign_course, coordinator), learner)

    data = summary(conn, coordinator, %{scope: "organization", organization_id: foreign.id})
    assert data["stats"]["members"] == 2
    assert data["stats"]["active_enrollments"] == 1
    assert data["stats"]["completed_enrollments"] == 1
    assert data["stats"]["available_courses"] == 1
    assert Enum.map(data["courses"], & &1["id"]) == [course.id]

    assert Enum.sort(Enum.map(data["members"], & &1["id"])) ==
             Enum.sort([coordinator.id, learner.id])

    assert [%{"course_id" => course_id, "enrollment_count" => 2, "completed_count" => 1}] =
             data["completion"]

    assert course_id == course.id
    learner_summary = Enum.find(data["members"], &(&1["id"] == learner.id))
    assert learner_summary["enrollment_count"] == 1
    assert learner_summary["completed_count"] == 1
  end

  test "totals cover all enrollments while response previews are bounded", ctx do
    %{conn: conn, learner: learner, org: org, teacher: teacher} = ctx
    course = course!(org, %{is_public: true})
    for _ <- 1..8, do: enroll!(class!(org, course, teacher), learner)
    data = summary(conn, learner)
    assert data["stats"]["active_enrollments"] == 8
    assert length(data["enrollments"]) == 6
  end
end
