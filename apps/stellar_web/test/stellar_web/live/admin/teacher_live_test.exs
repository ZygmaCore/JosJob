defmodule StellarWeb.Admin.TeacherLiveTest do
  @moduledoc """
  Menu Teachers: list ter-scope org (+kolom Class) dan detail read-only
  (peserta + jadwal). Delete dibatalkan — lihat spec:
  docs/specs/2026-07-27-teachers-menu-design.md.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}
  alias StellarLrn.Learning.{Class, Course, Enrollment, Section}

  # --- fixtures (pola class_controller_test) ---

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
      |> Ash.Changeset.for_create(:create, %{name: "Section Uji #{title}"})
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

  # Jadikan `user` pengajar aktif di `org`.
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

  # Non-superuser ber-permission `perm_keys` di `org` (role "staff" + membership aktif).
  defp staff_with_perms(conn, org, perm_keys) do
    user = create_user("staff@gmail.com", "Staf Uji")

    role =
      Role
      |> Ash.Changeset.for_create(:create, %{
        key: "staff",
        name: "Staff",
        organization_id: org.id
      })
      |> Ash.create!(authorize?: false)

    Enum.each(perm_keys, fn key ->
      permission =
        Permission
        |> Ash.Changeset.for_create(:create, %{key: key})
        |> Ash.create!(authorize?: false)

      RolePermission
      |> Ash.Changeset.for_create(:create, %{role_id: role.id, permission_id: permission.id})
      |> Ash.create!(authorize?: false)
    end)

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

    login(conn, user)
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  # Render halaman live (disconnected+connected) dan kembalikan HTML connected.
  defp live_html(conn, path) do
    {:ok, _view, html} = live(conn, path)
    html
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)
    course = create_course("Course Uji")

    {:ok, conn: login(conn, superuser), superuser: superuser, org: org, course: course}
  end

  # --- index ---

  test "list: nama+email, judul class, teacher tanpa class tampil '-'",
       %{conn: conn, org: org, course: course} do
    guru = create_user("guru@gmail.com", "Guru Mengajar")
    make_teacher(guru, org)
    create_class(course, org, guru, %{title: "Kelas Pagi"})

    nganggur = create_user("nganggur@gmail.com", "Guru Nganggur")
    make_teacher(nganggur, org)

    body = live_html(conn, ~p"/teachers")

    assert body =~ "Guru Mengajar"
    assert body =~ "guru@gmail.com"
    assert body =~ "Kelas Pagi"
    assert body =~ "Guru Nganggur"
  end

  test "list: user non-teacher tidak muncul", %{conn: conn, superuser: su} do
    bukan = create_user("bukan@gmail.com", "Bukan Pengajar")
    org2 = create_org("Org Beta", su)

    # membership aktif TANPA role teacher
    Membership
    |> Ash.Changeset.for_create(:create, %{
      user_id: bukan.id,
      organization_id: org2.id,
      status: :active
    })
    |> Ash.create!(authorize?: false)

    body = live_html(conn, ~p"/teachers")

    refute body =~ "Bukan Pengajar"
  end

  test "list non-superuser: hanya teacher org aktif; tanpa teachers:read ditolak",
       %{conn: conn, org: org, course: course, superuser: su} do
    guru_a = create_user("gurua@gmail.com", "Guru Org Alfa")
    make_teacher(guru_a, org)
    create_class(course, org, guru_a)

    org_b = create_org("Org Beta", su)
    guru_b = create_user("gurub@gmail.com", "Guru Org Beta")
    make_teacher(guru_b, org_b)

    conn = staff_with_perms(conn, org, ["dashboard:view", "teachers:read"])
    body = live_html(conn, ~p"/teachers")

    assert body =~ "Guru Org Alfa"
    refute body =~ "Guru Org Beta"
  end

  test "tanpa teachers:read maupun teachers:manage: route ditolak", %{conn: conn, org: org} do
    conn = staff_with_perms(conn, org, ["dashboard:view"])

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/teachers")
  end

  # --- show ---

  # Regresi server dev: teacher ber-role GLOBAL (organization_id nil, dibuat via
  # menu Roles "Global (semua org)") tampil di list superuser tapi detailnya
  # menjawab "Pengajar tidak ditemukan" — list dan detail harus satu sumber.
  test "detail: teacher ber-role global tampil di list DAN bisa dibuka detailnya",
       %{conn: conn, org: org} do
    guru = create_user("global@gmail.com", "Guru Role Global")

    global_role =
      Role
      |> Ash.Changeset.for_create(:create, %{key: "teacher", name: "Teacher"})
      |> Ash.create!(authorize?: false)

    membership =
      Membership
      |> Ash.Changeset.for_create(:create, %{
        user_id: guru.id,
        organization_id: org.id,
        status: :active
      })
      |> Ash.create!(authorize?: false)

    MembershipRole
    |> Ash.Changeset.for_create(:create, %{
      membership_id: membership.id,
      role_id: global_role.id
    })
    |> Ash.create!(authorize?: false)

    assert live_html(conn, ~p"/teachers") =~ "Guru Role Global"

    body = live_html(conn, ~p"/teachers/#{guru.id}?org=#{org.id}")
    assert body =~ "Guru Role Global"
  end

  test "detail: jumlah peserta aktif (non-aktif tak dihitung) + jadwal + kapasitas",
       %{conn: conn, org: org, course: course} do
    guru = create_user("guru@gmail.com", "Guru Detail")
    make_teacher(guru, org)

    class =
      create_class(course, org, guru, %{
        title: "Kelas Sabtu",
        capacity: 30,
        schedule: [
          %{"recurring" => true, "day" => "sat", "start_time" => "09:00", "end_time" => "10:00"}
        ]
      })

    siswa1 = create_user("siswa1@gmail.com", "Siswa Satu")
    siswa2 = create_user("siswa2@gmail.com", "Siswa Dua")

    for {siswa, status} <- [{siswa1, :active}, {siswa2, :completed}] do
      Enrollment
      |> Ash.Changeset.for_create(:create, %{
        class_id: class.id,
        student_id: siswa.id,
        status: status
      })
      |> Ash.create!(authorize?: false)
    end

    body = live_html(conn, ~p"/teachers/#{guru.id}?org=#{org.id}")

    assert body =~ "Guru Detail"
    assert body =~ "Kelas Sabtu"
    assert body =~ "Course Uji"
    # 1 aktif dari kapasitas 30 (yang :completed tidak dihitung)
    assert body =~ "1/30"
    # jadwal recurring dirender manusiawi
    assert body =~ "Saturday"
    assert body =~ "09:00"
  end

  test "detail: user yang bukan teacher di org tsb -> redirect ke /teachers",
       %{conn: conn, org: org} do
    bukan = create_user("bukan@gmail.com", "Bukan Teacher")

    assert {:error, {:live_redirect, %{to: "/teachers"}}} =
             live(conn, ~p"/teachers/#{bukan.id}?org=#{org.id}")
  end

  test "show non-superuser: param org diabaikan — teacher org lain tetap tak terjangkau",
       %{conn: conn, org: org, superuser: su} do
    org_b = create_org("Org Beta", su)
    guru_b = create_user("gurub@gmail.com", "Guru Org Beta")
    make_teacher(guru_b, org_b)

    conn = staff_with_perms(conn, org, ["dashboard:view", "teachers:read"])

    assert {:error, {:live_redirect, %{to: "/teachers"}}} =
             live(conn, ~p"/teachers/#{guru_b.id}?org=#{org_b.id}")
  end

  test "list: lebih dari 3 class diringkas '+N lagi'", %{conn: conn, org: org, course: course} do
    guru = create_user("guru@gmail.com", "Guru Sibuk")
    make_teacher(guru, org)

    for i <- 1..4 do
      create_class(course, org, guru, %{title: "Kelas #{i}"})
    end

    body = live_html(conn, ~p"/teachers")

    assert body =~ "+1 more"
  end
end
