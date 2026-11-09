defmodule StellarWeb.Admin.EnrollmentLiveTest do
  @moduledoc """
  Menu Enrollments versi LiveView: scoping per-org, filter kelas + cari siswa +
  pagination (URL), modal enroll (guard scope kelas), ubah status, hapus.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias StellarLrn.Learning.{Class, Course, Enrollment, Section}

  defp create_user(email, full_name, attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:create, Map.merge(%{email: email, full_name: full_name}, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_org(name, owner) do
    Organization
    |> Ash.Changeset.for_create(:create, %{name: name, user_id: owner.id})
    |> Ash.create!(authorize?: false)
  end

  defp create_class(title, org, instructor) do
    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Section #{title}"})
      |> Ash.create!(authorize?: false)

    course =
      Course
      |> Ash.Changeset.for_create(:create, %{title: "Course #{title}", section_id: section.id})
      |> Ash.create!(authorize?: false)

    Class
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      course_id: course.id,
      organization_id: org.id,
      instructor_id: instructor.id
    })
    |> Ash.create!(authorize?: false)
  end

  defp enroll(class, student, status \\ :active) do
    Enrollment
    |> Ash.Changeset.for_create(:create, %{
      class_id: class.id,
      student_id: student.id,
      status: status
    })
    |> Ash.create!(authorize?: false)
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)
    class = create_class("Kelas Alfa", org, superuser)

    {:ok, conn: login(conn, superuser), superuser: superuser, org: org, class: class}
  end

  test "filter kelas + cari nama siswa + URL", %{
    conn: conn,
    org: org,
    superuser: su,
    class: class
  } do
    siswa_a = create_user("andi@gmail.com", "Andi Wijaya")
    siswa_b = create_user("budi@gmail.com", "Budi Santoso")
    enroll(class, siswa_a)

    class_b = create_class("Kelas Beta", org, su)
    enroll(class_b, siswa_b)

    {:ok, view, html} = live(conn, ~p"/enrollments")
    assert html =~ "Andi Wijaya"
    assert html =~ "Budi Santoso"

    # filter per kelas
    view
    |> element("#enrollment-filter")
    |> render_change(%{"class_id" => class.id, "q" => "", "per_page" => "10"})

    assert_patch(view, ~p"/enrollments?class_id=#{class.id}")
    html = render(view)
    assert html =~ "Andi Wijaya"
    refute html =~ "Budi Santoso"

    # cari nama siswa
    view
    |> element("#enrollment-filter")
    |> render_change(%{"class_id" => "", "q" => "Budi", "per_page" => "10"})

    assert_patch(view, ~p"/enrollments?q=Budi")
    html = render(view)
    assert html =~ "Budi Santoso"
    refute html =~ "Andi Wijaya"
  end

  test "modal enroll: sukses; duplikat gagal dengan flash error", %{conn: conn, class: class} do
    siswa = create_user("siswa@gmail.com", "Siswa Uji")

    {:ok, view, _} = live(conn, ~p"/enrollments/new")
    assert has_element?(view, "#enrollment-modal")

    view
    |> element("#enrollment-modal form")
    |> render_submit(%{"enrollment" => %{"class_id" => class.id, "student_id" => siswa.id}})

    assert_patch(view, ~p"/enrollments")
    assert render(view) =~ "Siswa Uji"

    # duplikat
    {:ok, view, _} = live(conn, ~p"/enrollments/new")

    view
    |> element("#enrollment-modal form")
    |> render_submit(%{"enrollment" => %{"class_id" => class.id, "student_id" => siswa.id}})

    assert render(view) =~ "Failed to enroll"
  end

  test "non-superuser: scoped org aktif; enroll ke kelas org lain ditolak",
       %{superuser: su, org: org} do
    org_b = create_org("Org Beta", su)
    class_b = create_class("Kelas Beta", org_b, su)
    luar = create_user("luar@gmail.com", "Siswa Beta")
    enroll(class_b, luar)

    staff = create_user("staff@gmail.com", "Staf Uji")

    role =
      Stellar.Rbac.Role
      |> Ash.Changeset.for_create(:create, %{key: "staff", name: "Staff", organization_id: org.id})
      |> Ash.create!(authorize?: false)

    perm =
      Stellar.Rbac.Permission
      |> Ash.Changeset.for_create(:create, %{key: "enrollments:manage"})
      |> Ash.create!(authorize?: false)

    Stellar.Rbac.RolePermission
    |> Ash.Changeset.for_create(:create, %{role_id: role.id, permission_id: perm.id})
    |> Ash.create!(authorize?: false)

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: staff.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

    Stellar.Rbac.MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)

    conn = login(Phoenix.ConnTest.build_conn(), staff)

    {:ok, _view, html} = live(conn, ~p"/enrollments")
    refute html =~ "Siswa Beta"

    # enroll paksa ke kelas org lain -> ditolak, tak tersimpan
    {:ok, view, _} = live(conn, ~p"/enrollments/new")

    render_submit(view, "save", %{
      "enrollment" => %{"class_id" => class_b.id, "student_id" => staff.id}
    })

    assert render(view) =~ "permission"

    assert Enrollment
           |> Ash.Query.filter(class_id == ^class_b.id and student_id == ^staff.id)
           |> Ash.read!(authorize?: false) == []
  end

  test "ubah status + hapus", %{conn: conn, class: class} do
    siswa = create_user("siswa@gmail.com", "Siswa Uji")
    enr = enroll(class, siswa)

    {:ok, view, _} = live(conn, ~p"/enrollments")

    render_click(view, "set_status", %{"id" => enr.id, "status" => "completed"})
    assert Ash.get!(Enrollment, enr.id, authorize?: false).status == :completed

    view |> element(~s{[phx-click="delete"][phx-value-id="#{enr.id}"]}) |> render_click()
    refute has_element?(view, "#enrollments td", "Siswa Uji")
    assert render(view) =~ "Enrollment deleted."
  end

  test "pagination lewat URL", %{conn: conn, class: class} do
    for i <- 1..12 do
      siswa = create_user("siswa#{i}@gmail.com", "Siswa #{String.pad_leading("#{i}", 2, "0")}")
      enroll(class, siswa)
    end

    {:ok, view, html} = live(conn, ~p"/enrollments")
    assert html =~ "Page 1 of 2"

    view |> element("a", "Next »") |> render_click()
    assert_patch(view, ~p"/enrollments?page=2")
    assert render(view) =~ "Page 2 of 2"
  end
end
