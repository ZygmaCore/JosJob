defmodule StellarLrn.Learning do
  @moduledoc """
  Domain ekosistem course: Section → Course → Class → Enrollment.
  Material = dokumen di `StellarDoc.Documents` (dihubungkan lewat `course_id`).
  Pakai `Stellar.Repo`; enforcement lewat query-scope (bukan Ash policy global).
  """
  use Ash.Domain

  require Ash.Query
  alias StellarLrn.Learning.{Section, Course, Class, Enrollment}
  alias StellarDoc.Documents.Document

  resources do
    resource(Section)
    resource(StellarLrn.Learning.SectionOrganization)
    resource(Course)
    resource(StellarLrn.Learning.CourseOrganization)
    resource(StellarLrn.Learning.CourseIndustry)
    resource(Class)
    resource(StellarLrn.Learning.Enrollment)
  end

  @doc """
  Materi sebuah kelas = union:
    * materi kursus  → documents dengan `course_id` == course kelas ini
    * materi pengajar → documents milik instructor (`user_id`) yang `course_id` null
  """
  def materials_for_class(%Class{} = class), do: do_materials(class)

  def materials_for_class(class_id) when is_binary(class_id) do
    case Ash.get(Class, class_id, authorize?: false) do
      {:ok, class} -> do_materials(class)
      _ -> []
    end
  end

  defp do_materials(%Class{course_id: course_id, instructor_id: instructor_id}) do
    Document
    |> Ash.Query.filter(
      course_id == ^course_id or (user_id == ^instructor_id and is_nil(course_id))
    )
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Sisa slot kelas: `nil` bila kapasitas tak terbatas (`capacity` nil), selain itu
  `max(0, capacity - jumlah enrollment :active)`.
  """
  def seats_left(%Class{} = class), do: do_seats_left(class)

  def seats_left(class_id) when is_binary(class_id) do
    case Ash.get(Class, class_id, authorize?: false) do
      {:ok, class} -> do_seats_left(class)
      _ -> nil
    end
  end

  defp do_seats_left(%Class{capacity: nil}), do: nil

  defp do_seats_left(%Class{id: id, capacity: capacity}) do
    active =
      Enrollment
      |> Ash.Query.filter(class_id == ^id and status == :active)
      |> Ash.count!(authorize?: false)

    Kernel.max(capacity - active, 0)
  end

  @doc """
  Peran user pada sebuah kelas untuk sesi live (WebRTC):
    * `:host`  bila user adalah instructor kelas,
    * `:guest` bila user punya enrollment `:active` di kelas,
    * `nil`    selain itu (termasuk kelas tak ditemukan / id tak valid).

  Dipakai `StellarWeb.LiveRoomChannel` untuk MENURUNKAN role di server (bukan dari
  payload klien) sekaligus menggerbang akses room `class:<id>` ke pengajar + student
  yang ter-enroll saja.
  """
  def live_role(class_id, user_id) when is_binary(class_id) and is_binary(user_id) do
    case Ash.get(Class, class_id, authorize?: false) do
      {:ok, %Class{instructor_id: ^user_id}} -> :host
      {:ok, %Class{id: id}} -> if enrolled?(id, user_id), do: :guest, else: nil
      _ -> nil
    end
  rescue
    # id bukan UUID valid → Ash bisa raise; perlakukan sama dengan "tak berhak".
    _ -> nil
  end

  @doc "Apakah `user_id` punya enrollment `:active` di `class_id`."
  def enrolled?(class_id, user_id) when is_binary(class_id) and is_binary(user_id) do
    Enrollment
    |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  @doc "Section yang dimiliki tenant `org_id` (lewat join section_organizations)."
  def sections_for_org(org_id) when is_binary(org_id) do
    Section
    |> Ash.Query.filter(organizations.id == ^org_id)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
  end

  @doc "Course yang dipakai tenant `org_id` (lewat join course_organizations)."
  def courses_for_org(org_id) when is_binary(org_id) do
    Course
    |> Ash.Query.filter(organizations.id == ^org_id)
    |> Ash.Query.sort(title: :asc)
    |> Ash.read!(authorize?: false)
  end
end
