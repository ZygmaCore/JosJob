defmodule JosjobLrn.Overview do
  @moduledoc "Learning dashboard summaries derived from persisted enrollments and catalog data."
  require Ash.Query

  alias Josjob.Authz
  alias Josjob.Orgs.{Membership, Organization}
  alias JosjobLrn.Learning.{Class, Course, Enrollment}

  @preview_limit 6

  def fetch(user, "learner") do
    org_ids = Authz.member_orgs(user) |> Enum.map(& &1.id)
    studies = JosjobLrn.Curriculum.mine(user)
    study_ids = Enum.map(studies, & &1.id)

    enrollments =
      Enrollment
      |> Ash.Query.filter(student_id == ^user.id)
      |> Ash.Query.sort(enrolled_at: :desc, id: :asc)
      |> Ash.Query.load(class: [:instructor, course: :section])
      |> Ash.read!(authorize?: false)

    enrolled_ids = (Enum.map(enrollments, & &1.class.course_id) ++ study_ids) |> Enum.uniq()

    catalog =
      Course
      |> Ash.Query.filter(
        is_active == true and (is_public == true or organizations.id in ^org_ids)
      )

    available = Ash.count!(catalog, authorize?: false)

    courses =
      catalog
      |> Ash.Query.filter(id not in ^enrolled_ids)
      |> Ash.Query.sort(title: :asc, id: :asc)
      |> Ash.Query.limit(@preview_limit)
      |> Ash.Query.load(:section)
      |> Ash.read!(authorize?: false)

    active = Enum.filter(enrollments, &(&1.status == :active))
    sessions = active |> Enum.map(& &1.class) |> upcoming_sessions()

    {:ok,
     %{
       scope: "learner",
       stats: %{
         active_enrollments:
           Enum.count(active, &(&1.class.course_id not in study_ids)) +
             Enum.count(studies, &(&1.progress < 100)),
         completed_enrollments:
           Enum.count(
             enrollments,
             &(&1.status == :completed and &1.class.course_id not in study_ids)
           ) + Enum.count(studies, &(&1.progress == 100)),
         available_courses: available,
         upcoming_sessions: length(sessions)
       },
       enrollments:
         active
         |> Enum.reject(&(&1.class.course_id in study_ids))
         |> Enum.take(@preview_limit)
         |> Enum.map(&enrollment_json/1),
       course_studies: Enum.take(studies, @preview_limit),
       courses: Enum.map(courses, &course_json/1),
       upcoming_sessions: Enum.take(sessions, @preview_limit),
       members: [],
       completion: []
     }}
  end

  def fetch(user, "organization") do
    org_ids = managed_org_ids(user)

    if org_ids == [] do
      {:error, :forbidden}
    else
      organization_overview(org_ids)
    end
  end

  def fetch(_user, _scope), do: {:error, :invalid_scope}

  # Roster and enrollment summaries require both permissions in the SAME org.
  # Having a role in one tenant must never unlock another tenant's records.
  defp managed_org_ids(user) do
    if Authz.superuser?(user) do
      Organization |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
    else
      user
      |> Authz.member_orgs()
      |> Enum.filter(fn org ->
        permissions = Authz.permissions_for(user, org.id)

        Enum.all?(
          [
            ~w(members:read members:manage),
            ~w(courses:read courses:manage),
            ~w(enrollments:read enrollments:manage)
          ],
          fn alternatives -> Enum.any?(alternatives, &MapSet.member?(permissions, &1)) end
        )
      end)
      |> Enum.map(& &1.id)
    end
  end

  defp organization_overview(org_ids) do
    memberships =
      Membership
      |> Ash.Query.filter(organization_id in ^org_ids and status == :active)
      |> Ash.Query.load(:user)
      |> Ash.read!(authorize?: false)

    classes =
      Class
      |> Ash.Query.filter(organization_id in ^org_ids)
      |> Ash.Query.load([:instructor, course: :section])
      |> Ash.read!(authorize?: false)

    class_ids = Enum.map(classes, & &1.id)

    enrollments =
      Enrollment
      |> Ash.Query.filter(class_id in ^class_ids)
      |> Ash.Query.load(:class)
      |> Ash.read!(authorize?: false)

    courses =
      Course
      |> Ash.Query.filter(is_active == true and organizations.id in ^org_ids)
      |> Ash.Query.sort(title: :asc, id: :asc)
      |> Ash.Query.load(:section)
      |> Ash.read!(authorize?: false)

    members =
      memberships
      |> Enum.group_by(& &1.user_id)
      |> Enum.map(fn {user_id, memberships} ->
        member_orgs = Enum.map(memberships, & &1.organization_id)

        member_enrollments =
          Enum.filter(enrollments, fn enrollment ->
            enrollment.student_id == user_id and enrollment.class.organization_id in member_orgs
          end)

        %{
          id: user_id,
          name: hd(memberships).user.full_name,
          enrollment_count: length(member_enrollments),
          completed_count: Enum.count(member_enrollments, &(&1.status == :completed))
        }
      end)
      |> Enum.sort_by(&{&1.name || "", &1.id})

    completion =
      courses
      |> Enum.map(fn course ->
        course_enrollments = Enum.filter(enrollments, &(&1.class.course_id == course.id))

        %{
          course_id: course.id,
          title: course.title,
          enrollment_count: length(course_enrollments),
          completed_count: Enum.count(course_enrollments, &(&1.status == :completed))
        }
      end)

    sessions = upcoming_sessions(classes)

    {:ok,
     %{
       scope: "organization",
       stats: %{
         members: length(members),
         available_courses: length(courses),
         active_enrollments: Enum.count(enrollments, &(&1.status == :active)),
         completed_enrollments: Enum.count(enrollments, &(&1.status == :completed)),
         upcoming_sessions: length(sessions)
       },
       enrollments: [],
       courses: courses |> Enum.take(@preview_limit) |> Enum.map(&course_json/1),
       upcoming_sessions: Enum.take(sessions, @preview_limit),
       members: Enum.take(members, @preview_limit),
       completion: Enum.take(completion, @preview_limit)
     }}
  end

  defp enrollment_json(enrollment) do
    %{
      id: enrollment.id,
      status: enrollment.status,
      enrolled_at: enrollment.enrolled_at,
      class_id: enrollment.class_id,
      class_title: enrollment.class.title,
      course: course_json(enrollment.class.course)
    }
  end

  defp course_json(course) do
    %{
      id: course.id,
      title: course.title,
      description: course.description,
      section: course.section && course.section.name,
      price_cents: course.price_cents,
      currency: course.currency
    }
  end

  # Schedules store local wall-clock dates without a timezone. Include today's
  # sessions and future dates, and preserve their stored times without guessing
  # an offset or treating them as instants in the viewer's timezone.
  defp upcoming_sessions(classes) do
    today = Date.utc_today()

    classes
    |> Enum.uniq_by(& &1.id)
    |> Enum.flat_map(fn class ->
      Enum.flat_map(class.schedule, fn session ->
        case session_date(session) do
          {:ok, date} ->
            if Date.compare(date, today) in [:eq, :gt] do
              [
                %{
                  class_id: class.id,
                  class_title: class.title,
                  course_id: class.course_id,
                  course_title: class.course.title,
                  instructor: class.instructor && class.instructor.full_name,
                  date: Date.to_iso8601(date),
                  start: session_time(session["start"]),
                  end: session_time(session["end"])
                }
              ]
            else
              []
            end

          _ ->
            []
        end
      end)
    end)
    |> Enum.uniq_by(&{&1.class_id, &1.date, &1.start, &1.end})
    |> Enum.sort_by(&{&1.date, &1.start || "", &1.class_id})
  end

  defp session_date(%{"date" => date}) when is_binary(date), do: Date.from_iso8601(date)
  defp session_date(_), do: {:error, :invalid_date}

  defp session_time(time) when is_binary(time), do: time
  defp session_time(_), do: nil
end
