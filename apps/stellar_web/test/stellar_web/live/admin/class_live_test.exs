defmodule StellarWeb.Admin.ClassLiveTest do
  @moduledoc """
  Menu Classes versi LiveView — port seluruh perilaku ClassController lama:
  kolom Pengajar (teacher_pairs), dropdown pengajar ter-scope + tervalidasi,
  jadwal dinamis (kini murni LiveView, tanpa JS manual), panel peserta,
  dan Save & back to list.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Role}
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

  defp create_course(title) do
    section =
      Section
      |> Ash.Changeset.for_create(:create, %{name: "Section #{title}"})
      |> Ash.create!(authorize?: false)

    Course
    |> Ash.Changeset.for_create(:create, %{title: title, section_id: section.id})
    |> Ash.create!(authorize?: false)
  end

  defp create_class(course, org, instructor, attrs \\ %{}) do
    Class
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          title: "Kelas #{org.name}",
          course_id: course.id,
          organization_id: org.id,
          instructor_id: instructor && instructor.id
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp make_teacher(user, org) do
    role =
      Role
      |> Ash.Query.filter(key == "teacher" and organization_id == ^org.id)
      |> Ash.read!(authorize?: false)
      |> case do
        [r | _] ->
          r

        [] ->
          Role
          |> Ash.Changeset.for_create(:create, %{
            key: "teacher",
            name: "Teacher",
            organization_id: org.id
          })
          |> Ash.create!(authorize?: false)
      end

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: user.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

    MembershipRole
    |> Ash.Changeset.for_create(:create, %{membership_id: membership.id, role_id: role.id})
    |> Ash.create!(authorize?: false)

    role
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  defp class_params(course, org, extra) do
    Map.merge(
      %{
        "course_id" => course.id,
        "organization_id" => org.id,
        "title" => "Kelas Uji",
        "capacity" => ""
      },
      extra
    )
  end

  defp instructor_select(html) do
    [sel] = Regex.run(~r/<select[^>]*name="class\[instructor_id\]"[^>]*>.*?<\/select>/s, html)
    sel
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)
    course = create_course("Course Uji")

    {:ok, conn: login(conn, superuser), superuser: superuser, org: org, course: course}
  end

  # --- list ---

  test "list: nama instructor hanya tampil bila pengajar sah di org class",
       %{conn: conn, org: org, course: course} do
    outsider = create_user("outsider@gmail.com", "Bukan Pengajar Zulu")
    create_class(course, org, outsider)

    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    create_class(course, org, teacher, %{title: "Kelas Sah"})

    {:ok, _view, html} = live(conn, ~p"/classes")

    refute html =~ "Bukan Pengajar Zulu"
    assert html =~ "no instructor"
    assert html =~ "Pengajar Sah Alfa"
  end

  # --- form edit: dropdown pengajar ---

  test "edit: instructor non-pengajar tidak terpilih; pengajar sah terpilih; dropdown ter-scope org",
       %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    class_valid = create_class(course, org, teacher)

    org_b = create_org("Org Lain", create_user("owner2@gmail.com", "Owner Dua"))
    luar = create_user("luar@gmail.com", "Pengajar Org Lain")
    make_teacher(luar, org_b)
    class_invalid = create_class(course, org, luar)

    {:ok, _view, html} = live(conn, ~p"/classes/#{class_valid.id}/edit")
    sel = instructor_select(html)
    assert sel =~ ~r/<option[^>]*selected[^>]*#{teacher.id}/
    # ter-scope: teacher org lain tidak ditawarkan
    refute sel =~ ~r/<option[^>]*value="#{luar.id}"/

    {:ok, _view, html} = live(conn, ~p"/classes/#{class_invalid.id}/edit")
    sel = instructor_select(html)
    refute sel =~ ~r/<option[^>]*selected[^>]*#{luar.id}/
  end

  test "new superuser: dropdown pengajar disabled; ganti org mengisi opsi (reaktif)",
       %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)

    {:ok, view, html} = live(conn, ~p"/classes/new")
    sel = instructor_select(html)
    assert sel =~ ~r/<select[^>]*\sdisabled/
    assert length(Regex.scan(~r/<option/, sel)) == 1

    # pilih org lewat phx-change -> opsi pengajar terisi tanpa JS manual
    render_change(view, "validate", %{
      "class" => class_params(course, org, %{"instructor_id" => ""})
    })

    sel = instructor_select(render(view))
    refute sel =~ ~r/<select[^>]*\sdisabled/
    assert sel =~ ~r/<option[^>]*value="#{teacher.id}"/
  end

  # --- save ---

  test "update: pilih pengajar -> tersimpan + tampil di list; after_save=list ke index",
       %{conn: conn, org: org, course: course} do
    outsider = create_user("outsider@gmail.com", "Bukan Pengajar")
    class = create_class(course, org, outsider)

    teacher = create_user("teacher@gmail.com", "Pengajar Baru Beta")
    make_teacher(teacher, org)

    {:ok, view, _} = live(conn, ~p"/classes/#{class.id}/edit")

    # Save biasa -> tetap di halaman kelola
    view
    |> element("#class-form")
    |> render_submit(%{"class" => class_params(course, org, %{"instructor_id" => teacher.id})})

    assert Ash.get!(Class, class.id, authorize?: false).instructor_id == teacher.id
    assert render(view) =~ "Class updated."

    # Save & back to list -> navigate ke index dan nama tampil
    view
    |> element("#class-form")
    |> render_submit(%{
      "class" =>
        class_params(course, org, %{"instructor_id" => teacher.id, "after_save" => "list"})
    })

    assert_redirect(view, ~p"/classes")

    {:ok, _view, html} = live(conn, ~p"/classes")
    assert html =~ "Pengajar Baru Beta"
  end

  test "update: instructor tak sah di org class DITOLAK dan tak tersimpan",
       %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    class = create_class(course, org, teacher)

    org_b = create_org("Org Lain", create_user("owner2@gmail.com", "Owner Dua"))
    luar = create_user("luar@gmail.com", "Pengajar Org Lain")
    make_teacher(luar, org_b)

    {:ok, view, _} = live(conn, ~p"/classes/#{class.id}/edit")

    view
    |> element("#class-form")
    |> render_submit(%{"class" => class_params(course, org, %{"instructor_id" => luar.id})})

    assert render(view) =~ "not an active teacher"
    assert Ash.get!(Class, class.id, authorize?: false).instructor_id == teacher.id
  end

  # --- jadwal ---

  test "jadwal: tambah sesi recurring tersimpan ke bentuk jsonb; hapus baris",
       %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    class = create_class(course, org, teacher)

    {:ok, view, _} = live(conn, ~p"/classes/#{class.id}/edit")

    # tambah 1 baris (total 2), lalu hapus baris kedua (kembali 1)
    render_click(view, "add_session", %{})
    assert length(Regex.scan(~r/name="class\[schedule\]/, render(view))) > 8
    render_click(view, "remove_session", %{"idx" => "1"})

    view
    |> element("#class-form")
    |> render_submit(%{
      "class" =>
        class_params(course, org, %{
          "instructor_id" => teacher.id,
          "schedule" => %{
            "0" => %{
              "recurring" => "true",
              "day" => "sat",
              "start_hour" => "09",
              "start_minute" => "00",
              "end_hour" => "10",
              "end_minute" => "30"
            }
          }
        })
    })

    reloaded = Ash.get!(Class, class.id, authorize?: false)

    assert reloaded.schedule == [
             %{
               "recurring" => true,
               "day" => "sat",
               "start_time" => "09:00",
               "end_time" => "10:30"
             }
           ]
  end

  # --- panel peserta ---

  test "peserta: enroll member org, duplikat gagal, ubah status, hapus",
       %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    class = create_class(course, org, teacher)

    siswa = create_user("siswa@gmail.com", "Siswa Uji")

    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: siswa.id,
      organization_id: org.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)

    {:ok, view, _} = live(conn, ~p"/classes/#{class.id}/edit")

    # enroll
    view
    |> element("#enroll-form")
    |> render_submit(%{"student_id" => siswa.id})

    assert render(view) =~ "Student enrolled."
    assert has_element?(view, "#enrollments td", "Siswa Uji")

    [enr] =
      Enrollment |> Ash.Query.filter(class_id == ^class.id) |> Ash.read!(authorize?: false)

    # duplikat -> error (siswa sudah tidak ada di dropdown; tembak event langsung)
    render_submit(view, "add_enrollment", %{"student_id" => siswa.id})
    assert render(view) =~ "Enrollment failed"

    # ubah status -> completed
    render_click(view, "set_enrollment_status", %{"enr_id" => enr.id, "status" => "completed"})
    assert Ash.get!(Enrollment, enr.id, authorize?: false).status == :completed

    # hapus
    render_click(view, "remove_enrollment", %{"enr_id" => enr.id})
    refute has_element?(view, "#enrollments td", "Siswa Uji")
  end

  # --- delete & gate ---

  test "delete class dari list", %{conn: conn, org: org, course: course} do
    teacher = create_user("teacher@gmail.com", "Pengajar Sah Alfa")
    make_teacher(teacher, org)
    class = create_class(course, org, teacher, %{title: "Kelas Hapus"})

    {:ok, view, html} = live(conn, ~p"/classes")
    assert html =~ "Kelas Hapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{class.id}"]}) |> render_click()

    refute has_element?(view, "#classes td", "Kelas Hapus")
    assert render(view) =~ "Class deleted."
  end

  test "tanpa classes:*/enrollments:* di-redirect", %{org: org} do
    biasa = create_user("biasa@gmail.com", "User Biasa")

    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: biasa.id,
      organization_id: org.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)

    conn = login(Phoenix.ConnTest.build_conn(), biasa)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/classes")
  end
end
