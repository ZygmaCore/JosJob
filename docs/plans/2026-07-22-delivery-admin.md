# Delivery Admin (Class + Enrollment) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin web UI for the delivery layer — `Class` CRUD (instructor + schedule + capacity), full `Enrollment` management, and a read-only effective-materials view.

**Architecture:** One controller (`ClassController`) in `apps/stellar_web` mirroring `CourseController` (per-org scoping via `conn.assigns[:permissions]`, `authorize?: false`). Schedule is a jsonb list of `{start_date,end_date,recurring}` edited with dynamic rows (inline JS). Enrollment actions live on the same controller. One domain code change (`Enrollment` gains a `:set_status` action). **No migrations.**

**Tech Stack:** Phoenix 1.8 controllers + HEEx, AshPhoenix.Form, Ash 3, daisyUI, a little vanilla JS.

## Global Constraints

- **NEVER run git.** Commit steps are FYI checkpoints for the user.
- **No schema changes / no migrations.** Do not touch the dev DB. Runtime checks only on the TEST DB.
- Verify = `mix compile --warnings-as-errors` + `mix format --check-formatted` clean, then the user smoke-tests. **No controller tests** (repo has none / no auth harness).
- Reuse permissions `courses:read` (view) + `courses:manage` (create/edit/delete). No new keys.
- Follow existing helpers: `StellarWeb.Perms.can?/2`, `StellarWeb.Format.datetime/1`, `StellarWeb.Audit.user_labels/0`, `Layouts.admin` assigns.

---

### Task 1: `Enrollment` — allow status updates

**Files:**
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning/enrollment.ex`

**Interfaces:**
- Produces: `StellarLrn.Learning.Enrollment` action `:set_status` accepting `:status`.

- [ ] **Step 1: Add the `:set_status` action**

In `apps/stellar_lrn/lib/stellar_lrn/learning/enrollment.ex`, replace the `actions do ... end` block with:

```elixir
  actions do
    defaults([:read, :update, :destroy])

    create :create do
      accept([:class_id, :student_id, :status])
      change(StellarLrn.Learning.Changes.CheckCapacity)
    end

    update :set_status do
      accept([:status])
    end
  end
```

- [ ] **Step 2: Verify compile**

Run: `mix compile --warnings-as-errors`
Expected: clean.

- [ ] **Step 3: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn
git commit -m "feat(lrn): Enrollment :set_status action"
```

---

### Task 2: Class admin (CRUD + scoping + schedule + enrollment + materials)

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/class_controller.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/class_html.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/class_html/{index,new,edit}.html.heex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (class scope + enrollment routes)
- Modify: `apps/stellar_web/lib/stellar_web/components/layouts.ex` (sidebar "Classes")

**Interfaces:**
- Consumes: `StellarLrn.Learning.{Class, Course, Enrollment}`, `StellarLrn.Learning.materials_for_class/1`, `Stellar.Orgs.{Organization, Membership}`, `Stellar.Accounts.User`.
- Produces: routes `/classes` (index/new/create/edit/update/delete) + `/classes/:id/enrollments*`; `StellarWeb.Admin.ClassController`, `StellarWeb.Admin.ClassHTML`.

- [ ] **Step 1: Controller**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/class_controller.ex`:

```elixir
defmodule StellarWeb.Admin.ClassController do
  @moduledoc """
  CRUD Class (per-tenant) + kelola Enrollment. Route gate `courses:read`;
  create/edit/delete + enrollment butuh `courses:manage`. Superuser lihat semua &
  pilih org di form; non-superuser hanya class org aktif (org otomatis).

  `schedule` = daftar sesi {start_date, end_date, recurring} (jsonb), diedit via
  baris dinamis; domain tak menafsirkannya. Materi kelas ditampilkan read-only
  (materials_for_class); materi pengajar dikelola lewat /my/documents.
  """
  use StellarWeb, :controller

  import Phoenix.Component, only: [to_form: 1]
  require Ash.Query

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Class, Course, Enrollment}
  alias Stellar.Orgs.{Organization, Membership}
  alias Stellar.Accounts.User

  defp su?(conn), do: conn.assigns[:permissions] == :all
  defp can_manage?(conn), do: StellarWeb.Perms.can?(conn.assigns[:permissions], "courses:manage")
  defp active_org(conn), do: conn.assigns[:active_organization_id]

  defp forbid(conn),
    do:
      conn
      |> put_flash(:error, "Anda tidak punya izin untuk aksi itu.")
      |> redirect(to: ~p"/classes")

  defp base_scope(conn) do
    if su?(conn), do: Class, else: Ash.Query.filter(Class, organization_id == ^active_org(conn))
  end

  defp editable?(conn, %Class{} = class),
    do: can_manage?(conn) and (su?(conn) or class.organization_id == active_org(conn))

  def index(conn, _params) do
    classes =
      base_scope(conn)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:course, :instructor, :enrollments])
      |> Ash.read!(authorize?: false)

    render(conn, :index, classes: classes, org_names: org_name_map())
  end

  def new(conn, _params) do
    if can_manage?(conn),
      do: render(conn, :new, [form: to_form(create_form()), schedule_rows: [blank_row()]] ++ opts(conn)),
      else: forbid(conn)
  end

  def create(conn, %{"class" => params}) do
    if can_manage?(conn) do
      {schedule, rows} = parse_schedule(params)
      attrs = params |> Map.drop(["schedule"]) |> put_org(conn) |> Map.put("schedule", schedule)

      case AshPhoenix.Form.submit(create_form(conn.assigns.current_user), params: attrs) do
        {:ok, class} ->
          conn
          |> put_flash(:info, "Class dibuat.")
          |> redirect(to: ~p"/classes/#{class.id}/edit")

        {:error, form} ->
          render(conn, :new, [form: to_form(form), schedule_rows: rows] ++ opts(conn))
      end
    else
      forbid(conn)
    end
  end

  def edit(conn, %{"id" => id}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class),
      do: render(conn, :edit, edit_assigns(conn, class, to_form(update_form(class)), schedule_rows(class))),
      else: forbid(conn)
  end

  def update(conn, %{"id" => id, "class" => params}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class) do
      {schedule, rows} = parse_schedule(params)
      attrs = params |> Map.drop(["schedule"]) |> put_org(conn) |> Map.put("schedule", schedule)

      case AshPhoenix.Form.submit(update_form(class, conn.assigns.current_user), params: attrs) do
        {:ok, class} ->
          conn
          |> put_flash(:info, "Class diperbarui.")
          |> redirect(to: ~p"/classes/#{class.id}/edit")

        {:error, form} ->
          render(conn, :edit, edit_assigns(conn, class, to_form(form), rows))
      end
    else
      forbid(conn)
    end
  end

  def delete(conn, %{"id" => id}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class) do
      Ash.destroy!(class, authorize?: false)

      conn
      |> put_flash(:info, "Class dihapus.")
      |> redirect(to: ~p"/classes")
    else
      forbid(conn)
    end
  end

  # --- enrollments ---

  def add_enrollment(conn, %{"id" => id, "student_id" => student_id}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class) do
      result =
        Enrollment
        |> Ash.Changeset.for_create(:create, %{class_id: id, student_id: student_id})
        |> Ash.create(authorize?: false)

      conn
      |> flash_enroll(result)
      |> redirect(to: ~p"/classes/#{id}/edit")
    else
      forbid(conn)
    end
  end

  def remove_enrollment(conn, %{"id" => id, "enr_id" => enr_id}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class) do
      Enrollment |> Ash.get!(enr_id, authorize?: false) |> Ash.destroy!(authorize?: false)

      conn
      |> put_flash(:info, "Enrollment dihapus.")
      |> redirect(to: ~p"/classes/#{id}/edit")
    else
      forbid(conn)
    end
  end

  def set_enrollment_status(conn, %{"id" => id, "enr_id" => enr_id, "status" => status}) do
    class = Ash.get!(Class, id, authorize?: false)

    if editable?(conn, class) do
      Enrollment
      |> Ash.get!(enr_id, authorize?: false)
      |> Ash.Changeset.for_update(:set_status, %{status: status})
      |> Ash.update!(authorize?: false)

      conn
      |> put_flash(:info, "Status enrollment diperbarui.")
      |> redirect(to: ~p"/classes/#{id}/edit")
    else
      forbid(conn)
    end
  end

  defp flash_enroll(conn, {:ok, _}), do: put_flash(conn, :info, "Siswa didaftarkan.")
  defp flash_enroll(conn, {:error, _}),
    do: put_flash(conn, :error, "Gagal mendaftarkan (kelas penuh atau siswa sudah terdaftar).")

  # --- forms & assigns ---

  defp create_form(actor \\ nil),
    do: AshPhoenix.Form.for_create(Class, :create, as: "class", authorize?: false, actor: actor)

  defp update_form(class, actor \\ nil),
    do: AshPhoenix.Form.for_update(class, :update, as: "class", authorize?: false, actor: actor)

  # org untuk class: non-superuser paksa org aktif; superuser pakai yang dipilih di form.
  defp put_org(attrs, conn) do
    if su?(conn), do: attrs, else: Map.put(attrs, "organization_id", active_org(conn))
  end

  defp opts(conn) do
    [
      superuser: su?(conn),
      org_id: active_org(conn),
      org_options: Organization |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name) |> Enum.map(&{&1.name, &1.id}),
      course_options: course_options(conn),
      instructor_options: instructor_options(conn)
    ]
  end

  defp course_options(conn) do
    scope =
      if su?(conn),
        do: Course,
        else: Ash.Query.filter(Course, organizations.id == ^active_org(conn))

    scope
    |> Ash.Query.sort(title: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.title, &1.id})
  end

  defp instructor_options(conn) do
    if su?(conn),
      do: User |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.full_name) |> Enum.map(&user_opt/1),
      else: org_members(active_org(conn)) |> Enum.map(&user_opt/1)
  end

  defp user_opt(u), do: {"#{u.full_name} (#{u.email})", u.id}

  # User aktif di sebuah org (via Membership).
  defp org_members(nil), do: []

  defp org_members(org_id) do
    member_ids =
      Membership
      |> Ash.Query.filter(organization_id == ^org_id and status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)

    User
    |> Ash.Query.filter(id in ^member_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.full_name)
  end

  defp edit_assigns(conn, class, form, rows) do
    enrollments =
      Enrollment
      |> Ash.Query.filter(class_id == ^class.id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:student])
      |> Ash.read!(authorize?: false)

    enrolled_ids = Enum.map(enrollments, & &1.student_id)
    members = org_members(class.organization_id)

    [
      class: class,
      form: form,
      schedule_rows: rows,
      enrollments: enrollments,
      student_options:
        members |> Enum.reject(&(&1.id in enrolled_ids)) |> Enum.map(&user_opt/1),
      materials: Learning.materials_for_class(class)
    ] ++ opts(conn)
  end

  # --- schedule (jsonb list of {start_date, end_date, recurring}) ---

  defp blank_row, do: %{"start_date" => "", "end_date" => "", "recurring" => false}

  defp schedule_rows(%Class{schedule: list}) when is_list(list) and list != [] do
    Enum.map(list, fn m ->
      %{
        "start_date" => trim16(m["start_date"] || m[:start_date]),
        "end_date" => trim16(m["end_date"] || m[:end_date]),
        "recurring" => truthy(m["recurring"] || m[:recurring])
      }
    end)
  end

  defp schedule_rows(_), do: [blank_row()]

  # datetime-local butuh "YYYY-MM-DDTHH:MM" — potong bila tersimpan lebih panjang.
  defp trim16(nil), do: ""
  defp trim16(s) when is_binary(s), do: String.slice(s, 0, 16)

  # Parse rows dari params → {schedule_list, rows_untuk_render}. Baris tanpa start_date dibuang.
  defp parse_schedule(params) do
    raw =
      case Map.get(params, "schedule") do
        %{} = m -> Map.values(m)
        list when is_list(list) -> list
        _ -> []
      end

    rows =
      Enum.map(raw, fn r ->
        %{
          "start_date" => to_string(r["start_date"] || ""),
          "end_date" => to_string(r["end_date"] || ""),
          "recurring" => truthy(r["recurring"])
        }
      end)

    kept = Enum.reject(rows, &(&1["start_date"] == ""))
    rows = if rows == [], do: [blank_row()], else: rows
    {kept, rows}
  end

  defp truthy(v), do: v in [true, "true", "on", "1"]

  defp org_name_map do
    Organization |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.name})
  end
end
```

- [ ] **Step 2: HTML module + form component (with schedule rows + inline JS)**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/class_html.ex`:

```elixir
defmodule StellarWeb.Admin.ClassHTML do
  use StellarWeb, :html

  embed_templates "class_html/*"

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :method, :string, required: true
  attr :submit_label, :string, required: true
  attr :superuser, :boolean, required: true
  attr :org_id, :string, default: nil
  attr :org_options, :list, required: true
  attr :course_options, :list, required: true
  attr :instructor_options, :list, required: true
  attr :schedule_rows, :list, required: true

  def class_form(assigns) do
    ~H"""
    <.form for={@form} action={@action} method={@method} class="space-y-5">
      <input :if={not @superuser} type="hidden" name="class[organization_id]" value={@org_id} />

      <.input
        :if={@superuser}
        field={@form[:organization_id]}
        type="select"
        label="Organization (tenant)"
        options={@org_options}
        prompt="— Pilih tenant —"
        required
      />
      <.input
        field={@form[:course_id]}
        type="select"
        label="Course"
        options={@course_options}
        prompt="— Pilih course —"
        required
      />
      <.input
        field={@form[:instructor_id]}
        type="select"
        label="Pengajar"
        options={@instructor_options}
        prompt="— Pilih pengajar —"
        required
      />
      <.input field={@form[:title]} type="text" label="Judul kelas (opsional)" />
      <.input field={@form[:capacity]} type="number" label="Kapasitas (kosong = tak terbatas)" />

      <fieldset class="fieldset">
        <legend class="fieldset-legend">Jadwal (sesi)</legend>
        <div id="schedule-rows" class="space-y-2">
          <div :for={{row, i} <- Enum.with_index(@schedule_rows)} class="flex flex-wrap items-center gap-2">
            <input
              type="datetime-local"
              name={"class[schedule][#{i}][start_date]"}
              value={row["start_date"]}
              class="input input-bordered input-sm"
            />
            <span class="opacity-60">→</span>
            <input
              type="datetime-local"
              name={"class[schedule][#{i}][end_date]"}
              value={row["end_date"]}
              class="input input-bordered input-sm"
            />
            <label class="flex items-center gap-1 text-sm">
              <input
                type="checkbox"
                name={"class[schedule][#{i}][recurring]"}
                value="true"
                checked={row["recurring"]}
                class="checkbox checkbox-sm"
              /> Recurring
            </label>
            <button type="button" class="btn btn-ghost btn-xs text-error" onclick="this.parentElement.remove()">
              Hapus
            </button>
          </div>
        </div>
        <button type="button" class="btn btn-sm mt-2" onclick="addScheduleRow()">+ Tambah sesi</button>
      </fieldset>

      <div class="flex items-center gap-3">
        <.button variant="primary">{@submit_label}</.button>
        <.link navigate={~p"/classes"} class="btn btn-ghost">Batal</.link>
      </div>
    </.form>

    <script>
      function addScheduleRow() {
        var box = document.getElementById('schedule-rows');
        var i = 'n' + Date.now();
        var div = document.createElement('div');
        div.className = 'flex flex-wrap items-center gap-2';
        div.innerHTML =
          '<input type="datetime-local" name="class[schedule][' + i + '][start_date]" class="input input-bordered input-sm" />' +
          '<span class="opacity-60">→</span>' +
          '<input type="datetime-local" name="class[schedule][' + i + '][end_date]" class="input input-bordered input-sm" />' +
          '<label class="flex items-center gap-1 text-sm"><input type="checkbox" name="class[schedule][' + i + '][recurring]" value="true" class="checkbox checkbox-sm" /> Recurring</label>' +
          '<button type="button" class="btn btn-ghost btn-xs text-error" onclick="this.parentElement.remove()">Hapus</button>';
        box.appendChild(div);
      }
    </script>
    """
  end
end
```

- [ ] **Step 3: index template**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/class_html/index.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:classes}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Classes
    <:subtitle>Kelas (penyelenggaraan course oleh pengajar).</:subtitle>
    <:actions>
      <.link :if={StellarWeb.Perms.can?(@permissions, "courses:manage")} navigate={~p"/classes/new"}>
        <.button variant="primary">New class</.button>
      </.link>
    </:actions>
  </.header>

  <.table id="classes" rows={@classes}>
    <:col :let={c} label="Course">{c.course && c.course.title}</:col>
    <:col :let={c} label="Judul">{c.title}</:col>
    <:col :let={c} label="Pengajar">{c.instructor && c.instructor.full_name}</:col>
    <:col :let={c} label="Tenant">{@org_names[c.organization_id]}</:col>
    <:col :let={c} label="Sesi">{length(c.schedule)}</:col>
    <:col :let={c} label="Kapasitas">{c.capacity || "∞"}</:col>
    <:col :let={c} label="Terdaftar">{length(c.enrollments)}</:col>
    <:action :let={c}>
      <.link
        :if={StellarWeb.Perms.can?(@permissions, "courses:manage")}
        navigate={~p"/classes/#{c.id}/edit"}
        class="btn btn-ghost btn-xs"
      >
        Edit
      </.link>
    </:action>
    <:action :let={c}>
      <.link
        :if={StellarWeb.Perms.can?(@permissions, "courses:manage")}
        href={~p"/classes/#{c.id}"}
        method="delete"
        data-confirm="Hapus class ini?"
        class="btn btn-ghost btn-xs text-error"
      >
        Delete
      </.link>
    </:action>
  </.table>
</Layouts.admin>
```

- [ ] **Step 4: new template**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/class_html/new.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:classes}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>New class</.header>

  <.class_form
    form={@form}
    action={~p"/classes"}
    method="post"
    submit_label="Create"
    superuser={@superuser}
    org_id={@org_id}
    org_options={@org_options}
    course_options={@course_options}
    instructor_options={@instructor_options}
    schedule_rows={@schedule_rows}
  />
</Layouts.admin>
```

- [ ] **Step 5: edit template (form + enrollments + materials)**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/class_html/edit.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:classes}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Edit class
    <:subtitle>{@class.title}</:subtitle>
  </.header>

  <.class_form
    form={@form}
    action={~p"/classes/#{@class.id}"}
    method="put"
    submit_label="Save"
    superuser={@superuser}
    org_id={@org_id}
    org_options={@org_options}
    course_options={@course_options}
    instructor_options={@instructor_options}
    schedule_rows={@schedule_rows}
  />

  <div class="divider"></div>

  <section class="space-y-4">
    <h2 class="text-lg font-semibold">Peserta (enrollment)</h2>

    <.table id="enrollments" rows={@enrollments}>
      <:col :let={e} label="Siswa">{e.student && e.student.full_name}</:col>
      <:col :let={e} label="Status">{e.status}</:col>
      <:col :let={e} label="Terdaftar">{StellarWeb.Format.datetime(e.enrolled_at)}</:col>
      <:action :let={e}>
        <.link
          href={~p"/classes/#{@class.id}/enrollments/#{e.id}?status=#{if e.status == :active, do: "completed", else: "active"}"}
          method="patch"
          class="btn btn-ghost btn-xs"
        >
          {if e.status == :active, do: "Tandai selesai", else: "Aktifkan"}
        </.link>
      </:action>
      <:action :let={e}>
        <.link
          href={~p"/classes/#{@class.id}/enrollments/#{e.id}"}
          method="delete"
          data-confirm="Hapus enrollment ini?"
          class="btn btn-ghost btn-xs text-error"
        >
          Hapus
        </.link>
      </:action>
    </.table>

    <form
      :if={@student_options != []}
      action={~p"/classes/#{@class.id}/enrollments"}
      method="post"
      class="flex items-end gap-2"
    >
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <select name="student_id" class="select select-bordered select-sm">
        <option :for={{label, id} <- @student_options} value={id}>{label}</option>
      </select>
      <button class="btn btn-sm btn-primary">Daftarkan siswa</button>
    </form>
    <p :if={@student_options == []} class="text-sm opacity-70">
      Tak ada member org yang bisa didaftarkan (semua sudah terdaftar / belum ada member).
    </p>
  </section>

  <div class="divider"></div>

  <section class="space-y-2">
    <h2 class="text-lg font-semibold">Materi efektif kelas</h2>
    <p class="text-sm opacity-70">
      Materi course + materi pengajar. Materi pengajar dikelola lewat
      <.link navigate={~p"/my/documents"} class="link">Dokumen Saya</.link>.
    </p>
    <.table id="class-materials" rows={@materials}>
      <:col :let={m} label="Judul">{m.title}</:col>
      <:col :let={m} label="Tipe">{m.mime_type}</:col>
      <:col :let={m} label="URL"><a href={m.url} target="_blank" class="link">{m.url}</a></:col>
    </.table>
  </section>
</Layouts.admin>
```

- [ ] **Step 6: Router**

In `router.ex`, add a scope after the courses scope:

```elixir
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_courses_read]

    resources "/classes", ClassController, except: [:show]

    post "/classes/:id/enrollments", ClassController, :add_enrollment
    delete "/classes/:id/enrollments/:enr_id", ClassController, :remove_enrollment
    patch "/classes/:id/enrollments/:enr_id", ClassController, :set_enrollment_status
  end
```

- [ ] **Step 7: Sidebar entry**

In `layouts.ex` `admin_nav/0`, add after the `:courses` entry:

```elixir
      %{
        key: :classes,
        label: "Classes",
        path: "/classes",
        icon: "hero-user-group",
        permission: "courses:read"
      },
```

- [ ] **Step 8: Verify compile + format**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 9: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(web): class admin + enrollment management + effective materials"
```

---

### Task 3: Final verification

- [ ] **Step 1: Runtime sanity-check risky queries (TEST DB, throwaway)**

Run:
```bash
cd <path-ke-repo-stellar>
MIX_ENV=test mix run -e '
require Ash.Query
alias StellarLrn.Learning.{Class, Enrollment}
fake = Ash.UUID.generate()
Class |> Ash.Query.filter(organization_id == ^fake) |> Ash.Query.load([:course, :instructor, :enrollments]) |> Ash.read!(authorize?: false) |> length() |> then(&IO.puts("class scope+load OK -> #{&1}"))
Stellar.Orgs.Membership |> Ash.Query.filter(organization_id == ^fake and status == :active) |> Ash.read!(authorize?: false) |> length() |> then(&IO.puts("members OK -> #{&1}"))
'
```
Expected: both lines print `OK`, exit 0.

- [ ] **Step 2: Full suite (nothing breaks)**

Run: `mix test`
Expected: all pass (0 failures).

- [ ] **Step 3: Final compile + format**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: clean.

- [ ] **Step 4: Manual smoke checklist (USER, after `mix phx.server`)**
  - Superuser: `/classes` → New class (pick tenant, course, instructor, capacity, add 2 schedule rows) → save; on edit, enroll a student, mark completed, remove; effective materials list shows the course's materials.
  - Non-superuser (`coordinator`/`teacher`): `/classes` shows only active-org classes; New class has no tenant picker (auto active org); course/instructor dropdowns limited to the org.
  - Capacity: set capacity=1, enroll 2 → second rejected with flash. Enroll same student twice → rejected.

- [ ] **Step 5: Commit (USER runs git — do not execute)**

```bash
git add -A
git commit -m "chore(web): delivery admin complete"
```

---

## Post-plan handoff (not steps)
- **Git:** all commits are the user's. **No migrations** (no schema changes).
- **Next:** REST/Flutter student-facing flows (catalog browse, class browse, self-enroll).
