# Teachers Menu Implementation Plan

> **Status:** Task 1-4 selesai; Task 5 (Delete) DIBATALKAN saat implementasi — `Class.instructor_id` non-nullable; menu rilis read-only (lihat revisi di spec).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu admin "Teachers": list pengajar per org (+class yang diajar), halaman detail read-only (peserta + jadwal), dan delete = cabut role teacher + lepaskan dari class.

**Architecture:** Tidak ada entitas baru — "teacher" = user ber-membership aktif yang mengemban role `key == "teacher"`. Logika "siapa itu teacher" (sekarang privat di `ClassController`) diekstrak ke modul bersama `StellarWeb.Teachers`, lalu `TeacherController` (index/show/delete) memakai modul itu. Gate lewat permission baru `teachers:read`/`teachers:manage` yang di-seed.

**Tech Stack:** Phoenix controller klasik (bukan LiveView), Ash resources (`Stellar.Rbac.*`, `StellarLrn.Learning.*`), pola persis menu Classes.

**Spec:** `docs/specs/2026-07-27-teachers-menu-design.md`

## Global Constraints

- **JANGAN menjalankan git sama sekali** (add/commit/push) — user yang pegang git. Langkah "Commit" TIDAK ADA di plan ini, sengaja.
- Verifikasi akhir dari repo root: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `MIX_ENV=test mix test` — semuanya harus bersih (CI menjalankan ketiganya).
- Ikuti konvensi: komentar bahasa Indonesia gaya moduledoc yang ada; permission `manage` = superset `read`; semua query admin pakai `authorize?: false` (enforcement di web layer).
- Email fixture test harus domain nyata (`@gmail.com`) — validasi email resource User menolak domain aneh (pola ini dipakai semua test yang ada).

---

### Task 1: Seed permission `teachers:read` / `teachers:manage`

**Files:**
- Modify: `apps/stellar/lib/stellar/release.ex` (blok `@permissions`, setelah blok Enrollment ± baris 63-68)

**Interfaces:**
- Produces: key permission `"teachers:read"` dan `"teachers:manage"` (kategori `"learning"`) tersedia di katalog seed — dipakai Task 3 (router/nav) dan test.

- [ ] **Step 1: Tambah dua entri di `@permissions`**

Setelah blok `# Learning — Enrollment (peserta kelas)` (entri terakhirnya `{"enrollments:manage", ...}`), sisipkan:

```elixir
    # Learning — Teacher (menu Teachers: list/detail + cabut role)
    {"teachers:read", "learning", "Lihat pengajar & class yang diajar"},
    {"teachers:manage", "learning", "Kelola pengajar (cabut role teacher)"},
```

JANGAN menambah key ini ke `@roles` — pemberian ke role org dilakukan admin lewat UI Roles; superuser selalu lolos tanpa permission.

- [ ] **Step 2: Verifikasi**

Run: `mix compile --warnings-as-errors`
Expected: bersih (data module attribute, tidak ada logika baru).

---

### Task 2: Ekstrak `StellarWeb.Teachers` dari `ClassController` (refactor, perilaku tetap)

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/teachers.ex`
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/class_controller.ex` (hapus helper privat: `teacher_users/1`, `teacher_pairs/1`, `teacher_role_query/2`, `teacher_membership_ids/1`, `active_user_ids/2`; ganti pemanggilnya)
- Test: sudah ada — `apps/stellar_web/test/stellar_web/controllers/admin/class_controller_test.exs` (harus tetap hijau, tanpa diubah)

**Interfaces:**
- Produces (dipakai Task 3-5):
  - `StellarWeb.Teachers.teacher_users(org_id :: String.t() | nil) :: [User.t()]` — user ber-role teacher aktif; `nil` = semua org.
  - `StellarWeb.Teachers.teacher_rows(org_id :: String.t() | nil) :: [%{organization_id: String.t(), user: User.t()}]` — satu baris per pasangan org+user, urut nama.
  - `StellarWeb.Teachers.teacher_pairs(classes :: [Class.t()]) :: MapSet.t({org_id, user_id})`.

- [ ] **Step 1: Buat modul baru**

`apps/stellar_web/lib/stellar_web/teachers.ex` — badan `teacher_users/1`, `teacher_pairs/1`, dan privat-privatnya DISALIN APA ADANYA dari `ClassController` (jangan tulis ulang dari ingatan; buka filenya). Kerangka:

```elixir
defmodule StellarWeb.Teachers do
  @moduledoc """
  Query bersama "siapa itu teacher": user ber-role `key == "teacher"` (role milik
  org) dengan membership aktif di org tsb. Satu sumber kebenaran untuk
  ClassController (dropdown pengajar, kolom Pengajar) dan TeacherController
  (menu Teachers).
  """
  require Ash.Query

  alias Stellar.Accounts.User
  alias Stellar.Orgs.Membership
  alias Stellar.Rbac.{MembershipRole, Role}

  @doc "User ber-role teacher. `org_id` nil = semua org (superuser)."
  def teacher_users(org_id) do
    # << salin badan defp teacher_users/1 dari ClassController >>
  end

  @doc """
  Baris menu Teachers: satu entri per pasangan org+user (user bisa mengajar di
  lebih dari satu org), urut nama lalu email.
  """
  def teacher_rows(org_id) do
    role_ids =
      Role
      |> teacher_role_query(org_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    memberships =
      if role_ids == [] do
        []
      else
        Membership
        |> Ash.Query.filter(id in ^teacher_membership_ids(role_ids) and status == :active)
        |> then(fn q ->
          if org_id, do: Ash.Query.filter(q, organization_id == ^org_id), else: q
        end)
        |> Ash.read!(authorize?: false)
      end

    user_ids = memberships |> Enum.map(& &1.user_id) |> Enum.uniq()

    users_by_id =
      if user_ids == [],
        do: %{},
        else:
          User
          |> Ash.Query.filter(id in ^user_ids)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1})

    memberships
    |> Enum.map(&%{organization_id: &1.organization_id, user: users_by_id[&1.user_id]})
    |> Enum.uniq_by(&{&1.organization_id, &1.user.id})
    |> Enum.sort_by(&{&1.user.full_name, to_string(&1.user.email)})
  end

  @doc "Set {organization_id, user_id} pengajar aktif untuk org yang muncul di list class."
  def teacher_pairs(classes) do
    # << salin badan defp teacher_pairs/1 dari ClassController >>
  end

  # << salin defp teacher_role_query/2 (kedua klausa), teacher_membership_ids/1,
  #    active_user_ids/2 dari ClassController >>
end
```

- [ ] **Step 2: Ganti pemakaian di `ClassController`**

1. Hapus kelima helper privat tsb.
2. `teacher_users(org_id)` (di `instructor_options/1`) → `StellarWeb.Teachers.teacher_users(org_id)`.
3. `teacher_pairs(classes)` (di `index/2`) → `StellarWeb.Teachers.teacher_pairs(classes)`.
4. Kompilasi akan menunjukkan alias yang jadi yatim (kemungkinan `Role`, `MembershipRole` — CEK, `Membership` masih dipakai `org_members/1`); hapus hanya yang benar-benar tak terpakai.

- [ ] **Step 3: Verifikasi perilaku tak berubah**

Run: `mix compile --warnings-as-errors && MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/class_controller_test.exs`
Expected: compile bersih, test class (kolom Pengajar) tetap hijau tanpa diubah.

---

### Task 3: Route + nav + list `/teachers`

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_controller.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html/index.html.heex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (pipeline baru + scope baru, tiru pola `:require_classes_read` ± baris 63 dan scope `/classes` ± baris 254)
- Modify: `apps/stellar_web/lib/stellar_web/components/layouts.ex` (item `admin_nav` setelah `:classes` ± baris 268)
- Test: `apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs` (baru)
- Test: `apps/stellar_web/test/stellar_web/admin_nav_test.exs` (tambah 2 test)

**Interfaces:**
- Consumes: `StellarWeb.Teachers.teacher_rows/1` (Task 2), permission key (Task 1).
- Produces: route `GET /teachers` (index), helper HTML `class_label/1`, `class_summary/1`, `classes_of/2`, `delete_confirm/2` (dipakai Task 4-5); assigns index: `rows`, `classes_by`, `org_names`.

- [ ] **Step 1: Tulis failing test**

`apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`:

```elixir
defmodule StellarWeb.Admin.TeacherControllerTest do
  @moduledoc """
  Menu Teachers: list ter-scope org, kolom Class, detail read-only, dan delete
  (cabut role + lepaskan dari class). Spec: docs/specs/2026-07-27-teachers-menu-design.md.
  """
  use StellarWeb.ConnCase, async: false

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

  # Jadikan `user` pengajar aktif di `org`. Kembalikan role-nya (dipakai test delete).
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

    body = conn |> get(~p"/teachers") |> html_response(200)

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

    body = conn |> get(~p"/teachers") |> html_response(200)

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
    body = conn |> get(~p"/teachers") |> html_response(200)

    assert body =~ "Guru Org Alfa"
    refute body =~ "Guru Org Beta"
  end

  test "tanpa teachers:read maupun teachers:manage: route ditolak", %{conn: conn, org: org} do
    conn = staff_with_perms(conn, org, ["dashboard:view"])

    assert conn |> get(~p"/teachers") |> redirected_to() == "/"
  end
end
```

- [ ] **Step 2: Jalankan test — harus GAGAL**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`
Expected: FAIL — `no route found for GET /teachers`.

- [ ] **Step 3: Router — pipeline + scope**

Di `router.ex`, setelah pipeline `:require_classes_read`:

```elixir
  pipeline :require_teachers_read do
    plug StellarWeb.Plugs.RequirePermission, ["teachers:read", "teachers:manage"]
  end
```

Setelah scope Class admin:

```elixir
  # Menu Teachers (read-only + cabut role). Gate teachers:* (manage dicek di controller).
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_teachers_read]

    resources "/teachers", TeacherController, only: [:index, :show, :delete]
  end
```

(`:show` dan `:delete` diimplementasikan Task 4-5; route boleh sudah ada sekarang.)

- [ ] **Step 4: Controller (index dulu; show/delete menyusul di Task 4-5)**

`apps/stellar_web/lib/stellar_web/controllers/admin/teacher_controller.ex`:

```elixir
defmodule StellarWeb.Admin.TeacherController do
  @moduledoc """
  Menu Teachers (spec: docs/specs/2026-07-27-teachers-menu-design.md). "Teacher"
  = user ber-role `teacher` dengan membership aktif — bukan entitas sendiri.
  Route digate `teachers:read|manage`; delete butuh `teachers:manage`. Delete =
  cabut role teacher di org itu + kosongkan instructor class yang dia ajar.
  Non-superuser ter-scope org aktif; superuser lintas org (param `org` memilih
  konteks di show/delete).
  """
  use StellarWeb, :controller

  require Ash.Query

  alias StellarLrn.Learning.Class
  alias Stellar.Orgs.Organization
  alias StellarWeb.Teachers

  defp su?(conn), do: conn.assigns[:permissions] == :all
  defp active_org(conn), do: conn.assigns[:active_organization_id]

  def index(conn, _params) do
    org_id = if su?(conn), do: nil, else: active_org(conn)
    rows = Teachers.teacher_rows(org_id)

    render(conn, :index,
      rows: rows,
      classes_by: classes_by(rows),
      org_names: org_name_map()
    )
  end

  # Map {organization_id, user_id} => [class] (load course untuk judul).
  defp classes_by([]), do: %{}

  defp classes_by(rows) do
    org_ids = rows |> Enum.map(& &1.organization_id) |> Enum.uniq()
    user_ids = rows |> Enum.map(& &1.user.id) |> Enum.uniq()

    Class
    |> Ash.Query.filter(organization_id in ^org_ids and instructor_id in ^user_ids)
    |> Ash.Query.sort(created_at: :asc)
    |> Ash.Query.load([:course])
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(&{&1.organization_id, &1.instructor_id})
  end

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end
end
```

- [ ] **Step 5: HTML module + template index**

`apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html.ex`:

```elixir
defmodule StellarWeb.Admin.TeacherHTML do
  use StellarWeb, :html

  embed_templates "teacher_html/*"

  @doc "Class milik satu baris teacher (org+user) dari map hasil classes_by."
  def classes_of(classes_by, row), do: Map.get(classes_by, {row.organization_id, row.user.id}, [])

  @doc "Judul class untuk tampilan (fallback judul course bila title kosong)."
  def class_label(c), do: c.title || (c.course && c.course.title) || "(tanpa judul)"

  @doc "Ringkasan kolom Class: maks 3 judul lalu '+N lagi'; '-' bila belum mengajar."
  def class_summary([]), do: "-"

  def class_summary(classes) do
    {head, rest} = Enum.split(classes, 3)
    base = head |> Enum.map(&class_label/1) |> Enum.join(", ")
    if rest == [], do: base, else: "#{base} +#{length(rest)} lagi"
  end

  @doc "Kalimat konfirmasi delete — menyebut class yang akan kehilangan pengajar."
  def delete_confirm(row, []), do: "Cabut role teacher dari #{row.user.full_name}?"

  def delete_confirm(row, classes) do
    titles = classes |> Enum.map(&class_label/1) |> Enum.join(", ")

    "Cabut role teacher dari #{row.user.full_name}? " <>
      "#{length(classes)} class berikut akan kehilangan pengajar: #{titles}"
  end
end
```

`apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html/index.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:teachers}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Teachers
    <:subtitle>Pengajar aktif (user ber-role teacher) & class yang diajarnya.</:subtitle>
  </.header>

  <.table id="teachers" rows={@rows}>
    <:col :let={r} label="Nama">
      <div>{r.user.full_name}</div>
      <div class="text-xs opacity-60">{r.user.email}</div>
    </:col>
    <:col :let={r} label="Class">{class_summary(classes_of(@classes_by, r))}</:col>
    <:col :let={r} label="Tenant">{@org_names[r.organization_id]}</:col>
    <:action :let={r}>
      <.link
        navigate={~p"/teachers/#{r.user.id}?org=#{r.organization_id}"}
        class="btn btn-ghost btn-xs"
      >
        Detail
      </.link>
    </:action>
    <:action :let={r}>
      <.link
        :if={StellarWeb.Perms.can?(@permissions, ["teachers:manage"])}
        href={~p"/teachers/#{r.user.id}?org=#{r.organization_id}"}
        method="delete"
        data-confirm={delete_confirm(r, classes_of(@classes_by, r))}
        class="btn btn-ghost btn-xs text-error"
      >
        Delete
      </.link>
    </:action>
  </.table>
</Layouts.admin>
```

CATATAN: route `resources` juga membuat `:show`/`:delete`; sebelum Task 4-5 selesai, controller belum punya action itu — TIDAK apa-apa selama tidak ada request ke sana. Kalau compile router protes (tidak akan — Phoenix cek saat dispatch), lanjutkan saja.

- [ ] **Step 6: Item nav**

Di `layouts.ex` `admin_nav/0`, sisipkan setelah entri `:classes`:

```elixir
      %{
        key: :teachers,
        label: "Teachers",
        path: "/teachers",
        icon: "hero-user",
        permission: ["teachers:read", "teachers:manage"]
      },
```

- [ ] **Step 7: Test nav (2 test baru)**

Tambah di `apps/stellar_web/test/stellar_web/admin_nav_test.exs` (pakai `member_with_perms` yang sudah ada):

```elixir
  test "dengan teachers:read — menu Teachers tampil", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view", "teachers:read"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    assert body =~ ~s(href="/teachers")
  end

  test "tanpa teachers:* — menu Teachers hilang", %{conn: conn} do
    conn = member_with_perms(conn, ["dashboard:view"])
    body = conn |> get(~p"/dashboard") |> html_response(200)

    refute body =~ ~s(href="/teachers")
  end
```

- [ ] **Step 8: Jalankan test — harus HIJAU**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs apps/stellar_web/test/stellar_web/admin_nav_test.exs`
Expected: PASS semua (4 test controller + 5 test nav).

---

### Task 4: Halaman detail `/teachers/:id`

**Files:**
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_controller.ex` (action `show`)
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html.ex` (helper `session_label/1`, `participants_label/2`)
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html/show.html.heex`
- Test: `teacher_controller_test.exs` (tambah 2 test)

**Interfaces:**
- Consumes: `Teachers.teacher_users/1`, `classes_by/1` (privat Task 3), bentuk sesi `schedule` (jsonb, string key):
  - recurring: `%{"recurring" => true, "day" => "sat", "start_time" => "09:00", "end_time" => "10:00"}`
  - non-recurring: `%{"recurring" => false, "start_date" => "YYYY-MM-DDTHH:MM", "end_date" => "YYYY-MM-DDTHH:MM"}`
- Produces: assigns show: `user`, `org_id`, `org_name`, `classes` (course ter-load), `counts` (map class_id => jumlah peserta aktif), `can_open_class`.

- [ ] **Step 1: Tulis failing test (tambahkan di file test yang sama)**

```elixir
  # --- show ---

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

    body = conn |> get(~p"/teachers/#{guru.id}?org=#{org.id}") |> html_response(200)

    assert body =~ "Guru Detail"
    assert body =~ "Kelas Sabtu"
    assert body =~ "Course Uji"
    # 1 aktif dari kapasitas 30 (yang :completed tidak dihitung)
    assert body =~ "1/30"
    # jadwal recurring dirender manusiawi
    assert body =~ "Sabtu"
    assert body =~ "09:00"
  end

  test "detail: user yang bukan teacher di org tsb -> redirect ke /teachers",
       %{conn: conn, org: org} do
    bukan = create_user("bukan@gmail.com", "Bukan Teacher")

    conn = get(conn, ~p"/teachers/#{bukan.id}?org=#{org.id}")

    assert redirected_to(conn) == ~p"/teachers"
  end
```

- [ ] **Step 2: Jalankan — harus GAGAL**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`
Expected: FAIL — `UndefinedFunctionError ... show/2` (atau ActionClauseError).

- [ ] **Step 3: Implementasi `show` + helper + template**

Tambah di `TeacherController` (alias tambahan: `StellarLrn.Learning.Enrollment`, `Stellar.Accounts.User` TIDAK perlu — user dicari via `Teachers.teacher_users/1`):

```elixir
  def show(conn, %{"id" => user_id} = params) do
    org_id = resolve_org(conn, params)
    teacher = org_id && Enum.find(Teachers.teacher_users(org_id), &(&1.id == user_id))

    if teacher do
      classes =
        Class
        |> Ash.Query.filter(organization_id == ^org_id and instructor_id == ^user_id)
        |> Ash.Query.sort(created_at: :asc)
        |> Ash.Query.load([:course])
        |> Ash.read!(authorize?: false)

      render(conn, :show,
        user: teacher,
        org_id: org_id,
        org_name: org_name_map()[org_id],
        classes: classes,
        counts: active_counts(classes),
        can_open_class: can_open_class?(conn)
      )
    else
      conn
      |> put_flash(:error, "Pengajar tidak ditemukan di organisasi itu.")
      |> redirect(to: ~p"/teachers")
    end
  end

  # Konteks org: non-superuser selalu org aktif; superuser boleh memilih via ?org=
  # (link dari list selalu membawanya), fallback org aktif.
  defp resolve_org(conn, params) do
    if su?(conn), do: params["org"] || active_org(conn), else: active_org(conn)
  end

  # Peserta aktif per class (status :active; :completed tidak dihitung).
  defp active_counts(classes) do
    Map.new(classes, fn c ->
      n =
        Enrollment
        |> Ash.Query.filter(class_id == ^c.id and status == :active)
        |> Ash.count!(authorize?: false)

      {c.id, n}
    end)
  end

  # Boleh membuka /classes/:id/edit? — daftar izin yang sama dengan tombol
  # "Kelola" di list Classes.
  defp can_open_class?(conn) do
    StellarWeb.Perms.can?(conn.assigns[:permissions], [
      "classes:update",
      "classes:manage",
      "enrollments:read",
      "enrollments:create",
      "enrollments:update",
      "enrollments:delete",
      "enrollments:manage"
    ])
  end
```

Tambah di `TeacherHTML`:

```elixir
  @doc "Label peserta: 'N' atau 'N/kapasitas' bila capacity terisi."
  def participants_label(n, nil), do: to_string(n)
  def participants_label(n, capacity), do: "#{n}/#{capacity}"

  @doc """
  Label satu sesi jadwal (dua bentuk jsonb, string key; nilai recurring bisa
  boolean atau "true" — sama seperti normalize_row di ClassController).
  """
  def session_label(s) do
    if s["recurring"] in [true, "true"] do
      "#{day_label(s["day"])} #{s["start_time"]}–#{s["end_time"]}"
    else
      "#{fmt_dt(s["start_date"])} → #{fmt_dt(s["end_date"])}"
    end
  end

  # "YYYY-MM-DDTHH:MM" -> "YYYY-MM-DD HH:MM"
  defp fmt_dt(v), do: v |> to_string() |> String.replace("T", " ")

  defp day_label(d) do
    Map.get(
      %{
        "mon" => "Senin",
        "tue" => "Selasa",
        "wed" => "Rabu",
        "thu" => "Kamis",
        "fri" => "Jumat",
        "sat" => "Sabtu",
        "sun" => "Minggu"
      },
      to_string(d),
      to_string(d)
    )
  end
```

`apps/stellar_web/lib/stellar_web/controllers/admin/teacher_html/show.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:teachers}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    {@user.full_name}
    <:subtitle>{@user.email} — {@org_name}</:subtitle>
    <:actions>
      <.link navigate={~p"/teachers"} class="btn btn-ghost">Kembali</.link>
    </:actions>
  </.header>

  <p :if={@classes == []} class="opacity-60">Belum mengajar class apa pun.</p>

  <div :for={c <- @classes} class="card bg-base-200 mb-4">
    <div class="card-body">
      <h3 class="card-title text-base">
        <.link :if={@can_open_class} navigate={~p"/classes/#{c.id}/edit"} class="link">
          {class_label(c)}
        </.link>
        <span :if={!@can_open_class}>{class_label(c)}</span>
      </h3>
      <p class="text-sm opacity-70">Course: {c.course && c.course.title}</p>
      <p class="text-sm">Peserta aktif: {participants_label(@counts[c.id], c.capacity)}</p>
      <div class="text-sm">
        <span class="font-medium">Jadwal:</span>
        <ul :if={c.schedule != []} class="list-inside list-disc">
          <li :for={s <- c.schedule}>{session_label(s)}</li>
        </ul>
        <span :if={c.schedule == []} class="opacity-60">belum ada jadwal.</span>
      </div>
    </div>
  </div>
</Layouts.admin>
```

- [ ] **Step 4: Jalankan — harus HIJAU**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`
Expected: PASS semua.

---

### Task 5: Delete — cabut role + lepaskan dari class

**Files:**
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/teacher_controller.ex` (action `delete` + privat `revoke_teacher/2`)
- Test: `teacher_controller_test.exs` (tambah 3 test)

**Interfaces:**
- Consumes: `resolve_org/2` (Task 4), route `DELETE /teachers/:id` (Task 3).
- Produces: —(terminal). Efek: baris `membership_roles` role-teacher user di org terhapus; `instructor_id` class org tsb yang dia ajar jadi `nil`. User, membership, role lain, dan class org lain TIDAK berubah.

- [ ] **Step 1: Tulis failing test**

```elixir
  # --- delete ---

  test "delete: cabut role + kosongkan instructor; org lain & role lain utuh",
       %{conn: conn, org: org, course: course, superuser: su} do
    guru = create_user("guru@gmail.com", "Guru Dicabut")
    teacher_role = make_teacher(guru, org)
    class = create_class(course, org, guru)

    # dia juga teacher di org lain — TIDAK boleh tersentuh
    org_b = create_org("Org Beta", su)
    role_b = make_teacher(guru, org_b)
    class_b = create_class(course, org_b, guru)

    conn = delete(conn, ~p"/teachers/#{guru.id}?org=#{org.id}")
    assert redirected_to(conn) == ~p"/teachers"

    # role teacher di org Alfa tercabut
    assert MembershipRole
           |> Ash.Query.filter(role_id == ^teacher_role.id)
           |> Ash.read!(authorize?: false) == []

    # class org Alfa kehilangan pengajar
    assert Ash.get!(Class, class.id, authorize?: false).instructor_id == nil

    # org Beta utuh (role masih tertaut, class masih dia yang ajar)
    assert MembershipRole
           |> Ash.Query.filter(role_id == ^role_b.id)
           |> Ash.read!(authorize?: false) != []

    assert Ash.get!(Class, class_b.id, authorize?: false).instructor_id == guru.id

    # user & membership org Alfa tidak disentuh
    assert Ash.get!(User, guru.id, authorize?: false)

    assert Membership
           |> Ash.Query.filter(user_id == ^guru.id and organization_id == ^org.id)
           |> Ash.read!(authorize?: false)
           |> List.first()
           |> Map.fetch!(:status) == :active
  end

  test "delete tanpa teachers:manage ditolak dan tidak mengubah apa pun",
       %{conn: conn, org: org, course: course} do
    guru = create_user("guru@gmail.com", "Guru Aman")
    teacher_role = make_teacher(guru, org)
    class = create_class(course, org, guru)

    conn = staff_with_perms(conn, org, ["dashboard:view", "teachers:read"])
    conn = delete(conn, ~p"/teachers/#{guru.id}")

    assert redirected_to(conn) == ~p"/teachers"

    assert MembershipRole
           |> Ash.Query.filter(role_id == ^teacher_role.id)
           |> Ash.read!(authorize?: false) != []

    assert Ash.get!(Class, class.id, authorize?: false).instructor_id == guru.id
  end

  test "list: tombol Delete hanya tampil bila punya teachers:manage",
       %{conn: conn, org: org} do
    guru = create_user("guru@gmail.com", "Guru Tombol")
    make_teacher(guru, org)

    conn = staff_with_perms(conn, org, ["dashboard:view", "teachers:read"])
    body = conn |> get(~p"/teachers") |> html_response(200)

    assert body =~ "Detail"
    # penanda yang hanya ada di tombol Delete (label 'Delete' rawan whitespace HEEx)
    refute body =~ "data-confirm"
  end
```

- [ ] **Step 2: Jalankan — harus GAGAL**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`
Expected: FAIL — action `delete/2` belum ada.

- [ ] **Step 3: Implementasi `delete`**

Tambah di `TeacherController` (alias tambahan: `Stellar.Orgs.Membership`, `Stellar.Rbac.{MembershipRole, Role}`):

```elixir
  def delete(conn, %{"id" => user_id} = params) do
    org_id = resolve_org(conn, params)
    manage? = StellarWeb.Perms.can?(conn.assigns[:permissions], ["teachers:manage"])

    if manage? and is_binary(org_id) do
      revoke_teacher(user_id, org_id)

      conn
      |> put_flash(:info, "Role teacher dicabut; class terkait kini tanpa pengajar.")
      |> redirect(to: ~p"/teachers")
    else
      conn
      |> put_flash(:error, "Anda tidak punya izin untuk aksi itu.")
      |> redirect(to: ~p"/teachers")
    end
  end

  # Transaksional: (1) hapus tautan role teacher user di org, (2) kosongkan
  # instructor semua class org itu yang dia ajar. User/membership/role lain utuh.
  defp revoke_teacher(user_id, org_id) do
    {:ok, _} =
      Stellar.Repo.transaction(fn ->
        role_ids =
          Role
          |> Ash.Query.filter(key == "teacher" and organization_id == ^org_id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)

        membership_ids =
          Membership
          |> Ash.Query.filter(user_id == ^user_id and organization_id == ^org_id)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)

        if role_ids != [] and membership_ids != [] do
          MembershipRole
          |> Ash.Query.filter(role_id in ^role_ids and membership_id in ^membership_ids)
          |> Ash.read!(authorize?: false)
          |> Enum.each(&Ash.destroy!(&1, authorize?: false))
        end

        Class
        |> Ash.Query.filter(organization_id == ^org_id and instructor_id == ^user_id)
        |> Ash.read!(authorize?: false)
        |> Enum.each(fn class ->
          class
          |> Ash.Changeset.for_update(:update, %{instructor_id: nil})
          |> Ash.update!(authorize?: false)
        end)
      end)

    :ok
  end
```

- [ ] **Step 4: Jalankan — harus HIJAU**

Run: `MIX_ENV=test mix test apps/stellar_web/test/stellar_web/controllers/admin/teacher_controller_test.exs`
Expected: PASS semua (9 test).

---

### Task 6: Verifikasi akhir (gerbang selesai)

**Files:** — (tidak ada perubahan; hanya menjalankan verifikasi)

- [ ] **Step 1: Seluruh gerbang CI dari repo root**

Run: `mix compile --warnings-as-errors && mix format --check-formatted && MIX_ENV=test mix test`
Expected: compile bersih, format bersih, SEMUA test hijau (bukan hanya file baru — refactor Task 2 menyentuh ClassController).

- [ ] **Step 2: Smoke manual (opsional tapi dianjurkan)**

Jalankan server dev, login superuser, buka `/teachers`: list tampil, Detail menampilkan peserta+jadwal, tombol Delete memunculkan konfirmasi yang menyebut class terdampak. JANGAN commit — serahkan ke user.
