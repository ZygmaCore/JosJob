defmodule StellarWeb.Admin.CourseLiveTest do
  @moduledoc """
  Menu Courses (per-tenant) versi LiveView: list ter-scope org aktif (M:N),
  modal New (industri + tenant checkbox, sync join), edit full-page workspace
  (form + panel Materi: add/link/detach document), delete.
  """
  use StellarWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.{Industry, Membership, Organization}
  alias Stellar.Rbac.{MembershipRole, Permission, Role, RolePermission}
  alias StellarDoc.Documents.Document
  alias StellarLrn.Learning.{Course, CourseIndustry, CourseOrganization, Section}

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

  defp create_section(name) do
    Section
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  defp create_industry(name) do
    Industry
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  defp create_course(title, section, attrs \\ %{}) do
    Course
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{title: title, section_id: section.id}, attrs)
    )
    |> Ash.create!(authorize?: false)
  end

  defp link_org(course, org) do
    CourseOrganization
    |> Ash.Changeset.for_create(:create, %{course_id: course.id, organization_id: org.id})
    |> Ash.create!(authorize?: false)
  end

  defp create_document(title, user, org, course \\ nil) do
    Document
    |> Ash.Changeset.for_create(:create, %{
      title: title,
      url: "https://files.example.com/#{title}.pdf",
      user_id: user.id,
      organization_id: org.id,
      course_id: course && course.id
    })
    |> Ash.create!(authorize?: false)
  end

  defp staff_with_perms(org, perm_keys) do
    user = create_user("staff@gmail.com", "Staf Uji")

    role =
      Role
      |> Ash.Changeset.for_create(:create, %{key: "staff", name: "Staff", organization_id: org.id})
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

    {login(Phoenix.ConnTest.build_conn(), user), user}
  end

  defp login(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end

  defp course_org_ids(course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
  end

  defp course_industry_ids(course_id) do
    CourseIndustry
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.industry_id)
  end

  setup %{conn: conn} do
    superuser = create_user("su@gmail.com", "Super Admin", %{is_superuser: true})
    org = create_org("Org Alfa", superuser)
    org_b = create_org("Org Beta", superuser)
    section = create_section("Technology Information")

    {:ok,
     conn: login(conn, superuser), superuser: superuser, org: org, org_b: org_b, section: section}
  end

  test "tanpa courses:* di-redirect", %{org: org} do
    {conn, _} = staff_with_perms(org, ["dashboard:view"])

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/courses")
  end

  test "courses:read: list ter-scope org aktif; tombol New disembunyikan; /new ditolak",
       %{org: org, org_b: org_b, section: section} do
    course_a = create_course("Course Alfa", section)
    link_org(course_a, org)
    course_b = create_course("Course Beta", section)
    link_org(course_b, org_b)

    {conn, _} = staff_with_perms(org, ["courses:read"])

    {:ok, view, html} = live(conn, ~p"/courses")
    assert html =~ "Course Alfa"
    refute html =~ "Course Beta"
    refute has_element?(view, "a", "New course")

    assert {:error, {:live_redirect, %{to: "/courses", flash: %{"error" => msg}}}} =
             live(conn, ~p"/courses/new")

    assert msg =~ "permission"
  end

  test "courses:manage non-superuser: create via modal auto-linked ke org aktif + sync industri",
       %{org: org, section: section} do
    industry = create_industry("Fintech")
    {conn, _} = staff_with_perms(org, ["courses:manage"])

    {:ok, view, _} = live(conn, ~p"/courses/new")
    assert has_element?(view, "#course-modal")
    refute has_element?(view, "fieldset", "Share with tenant")

    view
    |> element("#course-modal form")
    |> render_submit(%{
      "course" => %{
        "section_id" => section.id,
        "title" => "Elixir Dasar",
        "description" => "Belajar Elixir",
        "is_active" => "true",
        "industry_ids" => [industry.id]
      }
    })

    assert_patch(view, ~p"/courses")

    course =
      Course |> Ash.Query.filter(title == "Elixir Dasar") |> Ash.read_one!(authorize?: false)

    assert course_org_ids(course.id) == [org.id]
    assert course_industry_ids(course.id) == [industry.id]
  end

  test "superuser: create dengan checkbox tenant, edit judul, update tanpa tenant tercentang menghapus tautan",
       %{conn: conn, org: org, org_b: org_b, section: section} do
    {:ok, view, _} = live(conn, ~p"/courses/new")
    assert has_element?(view, "fieldset", "Share with tenant")

    view
    |> element("#course-modal form")
    |> render_submit(%{
      "course" => %{
        "section_id" => section.id,
        "title" => "Go Programming",
        "description" => "Belajar Go",
        "is_active" => "true",
        "organization_ids" => [org.id, org_b.id]
      }
    })

    assert_patch(view, ~p"/courses")

    course =
      Course |> Ash.Query.filter(title == "Go Programming") |> Ash.read_one!(authorize?: false)

    assert Enum.sort(course_org_ids(course.id)) == Enum.sort([org.id, org_b.id])

    {:ok, view, _} = live(conn, ~p"/courses/#{course.id}/edit")
    assert has_element?(view, "h1, .text-lg", "Edit course")

    # uncheck semua tenant -> simulasikan phx-change validate dulu (pola RoleLive),
    # baru submit tanpa organization_ids sama sekali (destructive sync).
    render_change(view, "validate", %{
      "course" => %{
        "section_id" => section.id,
        "title" => "Go Programming Updated",
        "description" => "Belajar Go",
        "is_active" => "true"
      }
    })

    view
    |> element("form[phx-submit=save]")
    |> render_submit(%{
      "course" => %{
        "section_id" => section.id,
        "title" => "Go Programming Updated",
        "description" => "Belajar Go",
        "is_active" => "true"
      }
    })

    assert_patch(view, ~p"/courses")

    reloaded = Ash.get!(Course, course.id, authorize?: false)
    assert reloaded.title == "Go Programming Updated"
    assert course_org_ids(course.id) == []
  end

  test "edit workspace: panel materi add/link/detach", %{
    superuser: su,
    org: org,
    section: section
  } do
    course = create_course("Course Materi", section)
    link_org(course, org)
    linkable = create_document("bank-doc", su, org)

    {conn, _} = staff_with_perms(org, ["courses:manage"])

    {:ok, view, html} = live(conn, ~p"/courses/#{course.id}/edit")
    assert html =~ "bank-doc"

    # tambah materi baru
    view
    |> element("form[phx-submit=add_material]")
    |> render_submit(%{
      "document" => %{
        "title" => "Modul 1",
        "url" => "https://files.example.com/modul1.pdf",
        "mime_type" => "application/pdf",
        "description" => ""
      }
    })

    assert render(view) =~ "Modul 1"

    modul =
      Document |> Ash.Query.filter(title == "Modul 1") |> Ash.read_one!(authorize?: false)

    assert modul.course_id == course.id
    assert modul.organization_id == org.id

    # tautkan dokumen bank yang sudah ada
    view
    |> element("form[phx-submit=link_material]")
    |> render_submit(%{"document_id" => linkable.id})

    assert Ash.get!(Document, linkable.id, authorize?: false).course_id == course.id

    # lepas materi
    view
    |> element(~s{[phx-click="detach_material"][phx-value-doc_id="#{modul.id}"]})
    |> render_click()

    assert Ash.get!(Document, modul.id, authorize?: false).course_id == nil
  end

  test "non-superuser courses:manage tidak bisa edit course tenant lain (forbid)", %{
    org_b: org_b,
    section: section
  } do
    course = create_course("Course Luar", section)
    link_org(course, org_b)

    org = org_of_first_result()
    {conn, _} = staff_with_perms(org, ["courses:manage"])

    assert {:error, {:live_redirect, %{to: "/courses", flash: %{"error" => msg}}}} =
             live(conn, ~p"/courses/#{course.id}/edit")

    assert msg =~ "permission"
  end

  defp org_of_first_result do
    Organization |> Ash.Query.filter(name == "Org Alfa") |> Ash.read_one!(authorize?: false)
  end

  test "delete course menghapusnya dari list", %{conn: conn, section: section} do
    course = create_course("Course Hapus", section)

    {:ok, view, html} = live(conn, ~p"/courses")
    assert html =~ "Course Hapus"

    view |> element(~s{[phx-click="delete"][phx-value-id="#{course.id}"]}) |> render_click()

    refute has_element?(view, "#courses td", "Course Hapus")
    assert render(view) =~ "deleted"
  end
end
