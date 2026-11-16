defmodule JosjobWeb.Api.CatalogController do
  @moduledoc """
  Katalog student (Bearer). Course aktif yang dibagikan ke org tempat user jadi
  member. Detail menyertakan kelas (di org user) + materi.
  """
  use JosjobWeb, :controller

  require Ash.Query

  alias JosjobLrn.Learning
  alias JosjobLrn.Learning.{Course, Class, Enrollment}
  alias JosjobDoc.Documents.Document
  alias JosjobWeb.Api.StudentScope

  # GET /api/catalog/courses
  #
  # Course terlihat bila aktif DAN (publik ATAU dibagikan ke org tempat user jadi
  # member aktif). Publik = individual learner tanpa org tetap bisa menjelajah.
  def index(conn, _params) do
    org_ids = StudentScope.org_ids(conn.assigns.current_user)

    courses =
      Course
      |> Ash.Query.filter(
        is_active == true and (is_public == true or organizations.id in ^org_ids)
      )
      |> Ash.Query.sort(title: :asc)
      |> Ash.Query.load([:section, :industries, :classes])
      |> Ash.read!(authorize?: false)

    json(conn, %{data: Enum.map(courses, &course_summary_json/1)})
  end

  # GET /api/catalog/courses/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    org_ids = StudentScope.org_ids(user)

    course =
      Course
      |> Ash.Query.filter(
        id == ^id and is_active == true and
          (is_public == true or organizations.id in ^org_ids)
      )
      |> Ash.Query.load([:section, :industries])
      |> Ash.read_one!(authorize?: false)

    case course do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      course ->
        # Public course → semua kelasnya terlihat/bisa didaftari siapa saja;
        # course org-scoped → hanya kelas di org tempat user jadi member.
        class_query =
          if course.is_public do
            Ash.Query.filter(Class, course_id == ^course.id)
          else
            Ash.Query.filter(
              Class,
              course_id == ^course.id and organization_id in ^org_ids
            )
          end

        classes =
          class_query
          |> Ash.Query.sort(created_at: :asc)
          |> Ash.Query.load([:instructor])
          |> Ash.read!(authorize?: false)

        json(conn, %{data: course_detail_json(course, classes, user)})
    end
  end

  # --- JSON builders ---

  defp course_summary_json(course) do
    %{
      id: course.id,
      title: course.title,
      description: course.description,
      section: section_json(course.section),
      industries: Enum.map(course.industries, &%{id: &1.id, name: &1.name}),
      class_count: Enum.count(course.classes),
      price_cents: course.price_cents,
      currency: course.currency,
      is_free: free?(course)
    }
  end

  defp course_detail_json(course, classes, user) do
    %{
      id: course.id,
      title: course.title,
      description: course.description,
      section: section_json(course.section),
      industries: Enum.map(course.industries, &%{id: &1.id, name: &1.name}),
      price_cents: course.price_cents,
      currency: course.currency,
      is_free: free?(course),
      materials: course.id |> course_materials() |> Enum.map(&material_json/1),
      classes: Enum.map(classes, &class_json(&1, user))
    }
  end

  # A course is free when it has no positive price.
  defp free?(course), do: is_nil(course.price_cents) or course.price_cents <= 0

  defp section_json(nil), do: nil
  defp section_json(s), do: %{id: s.id, name: s.name}

  defp class_json(class, user) do
    %{
      id: class.id,
      title: class.title,
      schedule: class.schedule,
      capacity: class.capacity,
      seats_left: Learning.seats_left(class),
      instructor:
        class.instructor && %{id: class.instructor.id, full_name: class.instructor.full_name},
      enrolled: enrolled?(class.id, user.id),
      materials: class |> Learning.materials_for_class() |> Enum.map(&material_json/1)
    }
  end

  defp course_materials(course_id) do
    Document
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  defp material_json(d),
    do: %{
      id: d.id,
      title: d.title,
      url: d.url,
      mime_type: d.mime_type,
      description: d.description
    }

  defp enrolled?(class_id, user_id) do
    Enrollment
    |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end
end
