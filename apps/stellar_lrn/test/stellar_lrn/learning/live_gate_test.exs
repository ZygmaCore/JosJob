defmodule StellarLrn.Learning.LiveGateTest do
  @moduledoc """
  Gerbang enrollment untuk sesi live (WebRTC): `Learning.live_role/2` +
  `Learning.enrolled?/2`. Instructor → :host, student ter-enroll aktif → :guest,
  selain itu → nil (ditolak channel `live_room`).
  """
  use StellarLrn.DataCase, async: false

  alias Stellar.Accounts.User
  alias Stellar.Orgs.Organization
  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Class, Course, Enrollment, Section}

  setup do
    instructor = create_user!("instructor@example.com")
    student = create_user!("student@example.com")
    stranger = create_user!("stranger@example.com")

    org =
      Organization
      |> Ash.Changeset.for_create(:create, %{
        name: "Org #{System.unique_integer([:positive])}",
        user_id: instructor.id
      })
      |> Ash.create!(authorize?: false)

    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Tech"}, actor: instructor)
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(:create, %{title: "Go", section_id: section.id},
        actor: instructor
      )
      |> Ash.create!(authorize?: false)

    class =
      Class
      |> Ash.Changeset.for_create(:create, %{
        title: "Go — Batch 1",
        course_id: course.id,
        organization_id: org.id,
        instructor_id: instructor.id
      })
      |> Ash.create!(authorize?: false)

    Enrollment
    |> Ash.Changeset.for_create(:create, %{class_id: class.id, student_id: student.id})
    |> Ash.create!(authorize?: false)

    %{class: class, instructor: instructor, student: student, stranger: stranger}
  end

  describe "live_role/2" do
    test "instructor kelas → :host", %{class: class, instructor: instructor} do
      assert Learning.live_role(class.id, instructor.id) == :host
    end

    test "student ter-enroll aktif → :guest", %{class: class, student: student} do
      assert Learning.live_role(class.id, student.id) == :guest
    end

    test "user tak ter-enroll → nil (ditolak)", %{class: class, stranger: stranger} do
      assert Learning.live_role(class.id, stranger.id) == nil
    end

    test "class id tak dikenal → nil", %{student: student} do
      assert Learning.live_role(Ash.UUID.generate(), student.id) == nil
    end

    test "class id bukan UUID → nil (tidak crash)", %{student: student} do
      assert Learning.live_role("not-a-uuid", student.id) == nil
    end
  end

  describe "enrolled?/2" do
    test "true untuk student ter-enroll", %{class: class, student: student} do
      assert Learning.enrolled?(class.id, student.id)
    end

    test "false untuk yang bukan student", %{class: class, stranger: stranger} do
      refute Learning.enrolled?(class.id, stranger.id)
    end
  end

  defp create_user!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_email, %{
      email: email,
      full_name: "User",
      password: "password123"
    })
    |> Ash.create!(authorize?: false)
  end
end
