# Catalog Admin (Section + Course) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin web UI for the catalog layer — superuser CRUD for `Section`, and per-tenant RBAC-gated CRUD for `Course` (with industries M:N, tenant sharing, and a course-materials panel).

**Architecture:** Two controllers in `apps/stellar_web` following the existing pattern (`OrganizationController` for per-org scoping, `RoleController` for M:N checkbox sync). No schema changes — the `StellarLrn.Learning` domain + `StellarDoc.Documents` already exist. Web-layer enforcement (`authorize?: false`, RBAC via `conn.assigns[:permissions]`).

**Tech Stack:** Phoenix 1.8 controllers + HEEx, AshPhoenix.Form, Ash 3, daisyUI.

## Global Constraints

- **NEVER run git.** Commit steps are FYI checkpoints for the user; do not execute them.
- **No schema changes / no migrations** in this spec. Do not touch the dev DB.
- Verification = `mix compile --warnings-as-errors` + `mix format --check-formatted` clean, then the user smoke-tests manually. **No controller tests** (the repo has none and `ConnCase` has no auth helper).
- Reuse existing permissions: `courses:read` (view Course), `courses:manage` (create/edit/delete Course). Section = superuser-only via `:require_admin`. No new permission keys.
- Follow existing style: `StellarWeb.Perms.can?/2`, `StellarWeb.Format.datetime/1`, `StellarWeb.Audit.user_labels/0`, `Layouts.admin` assigns (`current_user`, `permissions`, `active_organization_id`, `member_orgs`).

---

### Task 1: Section admin (superuser-only)

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/section_controller.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/section_html.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/section_html/{index,new,edit}.html.heex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (add section resources to the superuser admin scope)
- Modify: `apps/stellar_web/lib/stellar_web/components/layouts.ex` (sidebar entry)

**Interfaces:**
- Produces: routes `/sections` (index/new/create/edit/update/delete) under `:require_admin`; `StellarWeb.Admin.SectionController`, `StellarWeb.Admin.SectionHTML`.

- [ ] **Step 1: Controller**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/section_controller.ex`:

```elixir
defmodule StellarWeb.Admin.SectionController do
  @moduledoc "CRUD Section (jurusan) — master-data global, superuser only."
  use StellarWeb, :controller

  import Phoenix.Component, only: [to_form: 1]
  require Ash.Query
  alias StellarLrn.Learning.Section

  def index(conn, _params) do
    sections = Section |> Ash.Query.sort(name: :asc) |> Ash.read!(authorize?: false)

    render(conn, :index, sections: sections, audit_labels: StellarWeb.Audit.user_labels())
  end

  def new(conn, _params), do: render(conn, :new, form: to_form(create_form()))

  def create(conn, %{"section" => params}) do
    case AshPhoenix.Form.submit(create_form(conn.assigns.current_user), params: params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Section #{section.name} dibuat.")
        |> redirect(to: ~p"/sections")

      {:error, form} ->
        render(conn, :new, form: to_form(form))
    end
  end

  def edit(conn, %{"id" => id}) do
    section = Ash.get!(Section, id, authorize?: false)
    render(conn, :edit, section: section, form: to_form(update_form(section)))
  end

  def update(conn, %{"id" => id, "section" => params}) do
    section = Ash.get!(Section, id, authorize?: false)

    case AshPhoenix.Form.submit(update_form(section, conn.assigns.current_user), params: params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Section #{section.name} diperbarui.")
        |> redirect(to: ~p"/sections")

      {:error, form} ->
        render(conn, :edit, section: section, form: to_form(form))
    end
  end

  def delete(conn, %{"id" => id}) do
    section = Ash.get!(Section, id, authorize?: false)

    case Ash.destroy(section, authorize?: false) do
      :ok ->
        conn
        |> put_flash(:info, "Section #{section.name} dihapus.")
        |> redirect(to: ~p"/sections")

      {:error, _} ->
        conn
        |> put_flash(:error, "Gagal menghapus (kemungkinan masih dipakai course).")
        |> redirect(to: ~p"/sections")
    end
  end

  defp create_form(actor \\ nil),
    do: AshPhoenix.Form.for_create(Section, :create, as: "section", authorize?: false, actor: actor)

  defp update_form(section, actor \\ nil),
    do: AshPhoenix.Form.for_update(section, :update, as: "section", authorize?: false, actor: actor)
end
```

- [ ] **Step 2: HTML module + form component**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/section_html.ex`:

```elixir
defmodule StellarWeb.Admin.SectionHTML do
  use StellarWeb, :html

  embed_templates "section_html/*"

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :method, :string, required: true
  attr :submit_label, :string, required: true

  def section_form(assigns) do
    ~H"""
    <.form for={@form} action={@action} method={@method} class="space-y-5">
      <.input field={@form[:name]} type="text" label="Nama section" required />
      <.input field={@form[:description]} type="textarea" label="Deskripsi" rows="3" />
      <.input field={@form[:is_active]} type="checkbox" label="Aktif" />

      <div class="flex items-center gap-3">
        <.button variant="primary">{@submit_label}</.button>
        <.link navigate={~p"/sections"} class="btn btn-ghost">Batal</.link>
      </div>
    </.form>
    """
  end
end
```

- [ ] **Step 3: Templates**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/section_html/index.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:sections}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Sections
    <:subtitle>Jurusan / kategori course (master-data global).</:subtitle>
    <:actions>
      <.link navigate={~p"/sections/new"}>
        <.button variant="primary">New section</.button>
      </.link>
    </:actions>
  </.header>

  <.table id="sections" rows={@sections}>
    <:col :let={s} label="Nama">{s.name}</:col>
    <:col :let={s} label="Deskripsi">{s.description}</:col>
    <:col :let={s} label="Aktif">{if s.is_active, do: "Ya", else: "Tidak"}</:col>
    <:col :let={s} label="Dibuat">{StellarWeb.Format.datetime(s.created_at)}</:col>
    <:col :let={s} label="Dibuat oleh">{@audit_labels[s.created_by] || "-"}</:col>
    <:action :let={s}>
      <.link navigate={~p"/sections/#{s.id}/edit"} class="btn btn-ghost btn-xs">Edit</.link>
    </:action>
    <:action :let={s}>
      <.link
        href={~p"/sections/#{s.id}"}
        method="delete"
        data-confirm={"Hapus section #{s.name}?"}
        class="btn btn-ghost btn-xs text-error"
      >
        Delete
      </.link>
    </:action>
  </.table>
</Layouts.admin>
```

Create `apps/stellar_web/lib/stellar_web/controllers/admin/section_html/new.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:sections}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>New section</.header>

  <.section_form form={@form} action={~p"/sections"} method="post" submit_label="Create" />
</Layouts.admin>
```

Create `apps/stellar_web/lib/stellar_web/controllers/admin/section_html/edit.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:sections}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Edit section
    <:subtitle>{@section.name}</:subtitle>
  </.header>

  <.section_form
    form={@form}
    action={~p"/sections/#{@section.id}"}
    method="put"
    submit_label="Save"
  />
</Layouts.admin>
```

- [ ] **Step 4: Route**

In `apps/stellar_web/lib/stellar_web/router.ex`, inside the superuser scope `scope "/", StellarWeb.Admin do pipe_through [:browser, :require_admin]`, add (next to `resources "/industries", ...`):

```elixir
    resources "/sections", SectionController, except: [:show]
```

- [ ] **Step 5: Sidebar entry**

In `apps/stellar_web/lib/stellar_web/components/layouts.ex`, inside `admin_nav/0`, add after the `:industries` entry:

```elixir
      %{
        key: :sections,
        label: "Sections",
        path: "/sections",
        icon: "hero-rectangle-stack",
        visible: :superuser
      },
```

- [ ] **Step 6: Verify**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean. (Manual smoke later: `/sections` lists, create/edit/delete work; hidden from non-superuser.)

- [ ] **Step 7: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(web): section admin (superuser)"
```

---

### Task 2: Course admin (per-tenant CRUD + industries M:N + tenant sharing)

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/course_controller.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/course_html.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/course_html/{index,new,edit}.html.heex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (new `:require_courses_read` pipeline + course scope)
- Modify: `apps/stellar_web/lib/stellar_web/components/layouts.ex` (sidebar entry)

**Interfaces:**
- Consumes: `StellarLrn.Learning.{Course, Section, CourseOrganization, CourseIndustry}`, `Stellar.Orgs.{Organization, Industry}`.
- Produces: routes `/courses` (index/new/create/edit/update/delete) under `[:browser, :require_member, :require_courses_read]`; `StellarWeb.Admin.CourseController`, `StellarWeb.Admin.CourseHTML`. The `edit` action assigns needed by Task 3's materials panel are added in Task 3.

- [ ] **Step 1: `:require_courses_read` pipeline**

In `router.ex`, next to `pipeline :require_orgs_read do ... end`, add:

```elixir
  pipeline :require_courses_read do
    plug StellarWeb.Plugs.RequirePermission, "courses:read"
  end
```

- [ ] **Step 2: Controller**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/course_controller.ex`:

```elixir
defmodule StellarWeb.Admin.CourseController do
  @moduledoc """
  CRUD Course (per-tenant). Route gate `courses:read`; create/edit/delete butuh
  `courses:manage`. Superuser lihat semua + bagikan ke banyak tenant; non-superuser
  hanya course yang tertaut ke org aktifnya, dan course baru otomatis tertaut ke
  org aktif. Industri = M:N (checkbox). Section = dropdown semua section aktif.
  """
  use StellarWeb, :controller

  import Phoenix.Component, only: [to_form: 1]
  require Ash.Query

  alias StellarLrn.Learning.{Course, Section, CourseOrganization, CourseIndustry}
  alias Stellar.Orgs.{Organization, Industry}

  defp su?(conn), do: conn.assigns[:permissions] == :all
  defp can_manage?(conn), do: StellarWeb.Perms.can?(conn.assigns[:permissions], "courses:manage")
  defp active_org(conn), do: conn.assigns[:active_organization_id]

  defp forbid(conn),
    do:
      conn
      |> put_flash(:error, "Anda tidak punya izin untuk aksi itu.")
      |> redirect(to: ~p"/courses")

  # Superuser lihat semua; non-superuser hanya course yang tertaut ke org aktif.
  defp base_scope(conn) do
    if su?(conn),
      do: Course,
      else: Ash.Query.filter(Course, organizations.id == ^active_org(conn))
  end

  # Course tertaut ke org aktif? (untuk izin edit non-superuser).
  defp in_active_org?(conn, course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id and organization_id == ^active_org(conn))
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp editable?(conn, course_id),
    do: can_manage?(conn) and (su?(conn) or in_active_org?(conn, course_id))

  def index(conn, _params) do
    courses =
      base_scope(conn)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load([:section, :industries])
      |> Ash.read!(authorize?: false)

    render(conn, :index,
      courses: courses,
      audit_labels: StellarWeb.Audit.user_labels()
    )
  end

  def new(conn, _params) do
    if can_manage?(conn),
      do: render(conn, :new, [form: to_form(create_form())] ++ opts(conn, [], [])),
      else: forbid(conn)
  end

  def create(conn, %{"course" => params}) do
    if can_manage?(conn) do
      {industry_ids, org_ids, attrs} = pop_join_ids(conn, params)

      case AshPhoenix.Form.submit(create_form(conn.assigns.current_user), params: attrs) do
        {:ok, course} ->
          sync_industries(course.id, industry_ids)
          sync_organizations(course.id, org_ids)

          conn
          |> put_flash(:info, "Course #{course.title} dibuat.")
          |> redirect(to: ~p"/courses")

        {:error, form} ->
          render(conn, :new, [form: to_form(form)] ++ opts(conn, industry_ids, org_ids))
      end
    else
      forbid(conn)
    end
  end

  def edit(conn, %{"id" => id}) do
    if editable?(conn, id) do
      course = Ash.get!(Course, id, authorize?: false)

      render(
        conn,
        :edit,
        [course: course, form: to_form(update_form(course))] ++
          opts(conn, course_industry_ids(id), course_org_ids(id))
      )
    else
      forbid(conn)
    end
  end

  def update(conn, %{"id" => id, "course" => params}) do
    if editable?(conn, id) do
      course = Ash.get!(Course, id, authorize?: false)
      {industry_ids, org_ids, attrs} = pop_join_ids(conn, params)

      case AshPhoenix.Form.submit(update_form(course, conn.assigns.current_user), params: attrs) do
        {:ok, course} ->
          sync_industries(course.id, industry_ids)
          # Non-superuser tidak boleh mengubah tautan tenant (biarkan apa adanya).
          if su?(conn), do: sync_organizations(course.id, org_ids)

          conn
          |> put_flash(:info, "Course #{course.title} diperbarui.")
          |> redirect(to: ~p"/courses")

        {:error, form} ->
          render(conn, :edit, [course: course, form: to_form(form)] ++ opts(conn, industry_ids, org_ids))
      end
    else
      forbid(conn)
    end
  end

  def delete(conn, %{"id" => id}) do
    if editable?(conn, id) do
      course = Ash.get!(Course, id, authorize?: false)
      # Lepas materi (documents.course_id) agar tak jadi orphan; join M:N drop via FK.
      detach_materials(id)

      case Ash.destroy(course, authorize?: false) do
        :ok ->
          conn
          |> put_flash(:info, "Course #{course.title} dihapus.")
          |> redirect(to: ~p"/courses")

        {:error, _} ->
          conn
          |> put_flash(:error, "Gagal menghapus course.")
          |> redirect(to: ~p"/courses")
      end
    else
      forbid(conn)
    end
  end

  # --- forms ---

  defp create_form(actor \\ nil),
    do: AshPhoenix.Form.for_create(Course, :create, as: "course", authorize?: false, actor: actor)

  defp update_form(course, actor \\ nil),
    do: AshPhoenix.Form.for_update(course, :update, as: "course", authorize?: false, actor: actor)

  # Assigns umum untuk new/edit.
  defp opts(conn, industry_checked, org_checked) do
    [
      superuser: su?(conn),
      section_options: section_options(),
      industry_options: Industry |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name),
      org_options:
        Organization |> Ash.read!(authorize?: false) |> Enum.sort_by(& &1.name),
      industry_checked: industry_checked,
      org_checked: org_checked
    ]
  end

  defp section_options do
    Section
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.name, &1.id})
  end

  # Pisahkan industry_ids/organization_ids dari atribut course. Non-superuser:
  # abaikan org yang dikirim, paksa ke org aktif.
  defp pop_join_ids(conn, params) do
    industry_ids = params |> Map.get("industry_ids", []) |> List.wrap() |> clean_ids()

    org_ids =
      if su?(conn),
        do: params |> Map.get("organization_ids", []) |> List.wrap() |> clean_ids(),
        else: [active_org(conn)]

    {industry_ids, org_ids, params |> Map.drop(["industry_ids", "organization_ids"])}
  end

  defp clean_ids(ids), do: Enum.reject(ids, &(&1 in ["", nil]))

  # Set join agar persis = ids (hapus semua, buat ulang) — pola sama seperti RoleController.
  defp sync_industries(course_id, ids) do
    CourseIndustry
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Enum.each(ids, fn iid ->
      CourseIndustry
      |> Ash.Changeset.for_create(:create, %{course_id: course_id, industry_id: iid})
      |> Ash.create!(authorize?: false)
    end)
  end

  defp sync_organizations(course_id, ids) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    Enum.each(ids, fn oid ->
      CourseOrganization
      |> Ash.Changeset.for_create(:create, %{course_id: course_id, organization_id: oid})
      |> Ash.create!(authorize?: false)
    end)
  end

  defp course_industry_ids(course_id) do
    CourseIndustry
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.industry_id)
  end

  defp course_org_ids(course_id) do
    CourseOrganization
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
  end

  defp detach_materials(course_id) do
    StellarDoc.Documents.Document
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn doc ->
      doc
      |> Ash.Changeset.for_update(:update, %{course_id: nil})
      |> Ash.update!(authorize?: false)
    end)
  end
end
```

- [ ] **Step 3: HTML module + form component**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/course_html.ex`:

```elixir
defmodule StellarWeb.Admin.CourseHTML do
  use StellarWeb, :html

  embed_templates "course_html/*"

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :method, :string, required: true
  attr :submit_label, :string, required: true
  attr :superuser, :boolean, required: true
  attr :section_options, :list, required: true
  attr :industry_options, :list, required: true
  attr :org_options, :list, required: true
  attr :industry_checked, :list, required: true
  attr :org_checked, :list, required: true

  def course_form(assigns) do
    ~H"""
    <.form for={@form} action={@action} method={@method} class="space-y-5">
      <.input
        field={@form[:section_id]}
        type="select"
        label="Section"
        options={@section_options}
        prompt="— Pilih section —"
        required
      />
      <.input field={@form[:title]} type="text" label="Judul course" required />
      <.input field={@form[:description]} type="textarea" label="Deskripsi" rows="3" />
      <.input field={@form[:is_active]} type="checkbox" label="Aktif" />

      <fieldset class="fieldset">
        <legend class="fieldset-legend">Industri</legend>
        <div class="flex flex-wrap gap-3">
          <label :for={i <- @industry_options} class="flex items-center gap-2">
            <input
              type="checkbox"
              name="course[industry_ids][]"
              value={i.id}
              checked={i.id in @industry_checked}
              class="checkbox checkbox-sm"
            />
            {i.name}
          </label>
        </div>
      </fieldset>

      <fieldset :if={@superuser} class="fieldset">
        <legend class="fieldset-legend">Bagikan ke tenant</legend>
        <div class="flex flex-wrap gap-3">
          <label :for={o <- @org_options} class="flex items-center gap-2">
            <input
              type="checkbox"
              name="course[organization_ids][]"
              value={o.id}
              checked={o.id in @org_checked}
              class="checkbox checkbox-sm"
            />
            {o.name}
          </label>
        </div>
      </fieldset>

      <div class="flex items-center gap-3">
        <.button variant="primary">{@submit_label}</.button>
        <.link navigate={~p"/courses"} class="btn btn-ghost">Batal</.link>
      </div>
    </.form>
    """
  end
end
```

- [ ] **Step 4: index template**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/course_html/index.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:courses}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Courses
    <:subtitle>Katalog course.</:subtitle>
    <:actions>
      <.link :if={StellarWeb.Perms.can?(@permissions, "courses:manage")} navigate={~p"/courses/new"}>
        <.button variant="primary">New course</.button>
      </.link>
    </:actions>
  </.header>

  <.table id="courses" rows={@courses}>
    <:col :let={c} label="Judul">{c.title}</:col>
    <:col :let={c} label="Section">{c.section && c.section.name}</:col>
    <:col :let={c} label="Aktif">{if c.is_active, do: "Ya", else: "Tidak"}</:col>
    <:col :let={c} label="Industri">{Enum.map_join(c.industries, ", ", & &1.name)}</:col>
    <:col :let={c} label="Dibuat">{StellarWeb.Format.datetime(c.created_at)}</:col>
    <:col :let={c} label="Dibuat oleh">{@audit_labels[c.created_by] || "-"}</:col>
    <:action :let={c}>
      <.link
        :if={StellarWeb.Perms.can?(@permissions, "courses:manage")}
        navigate={~p"/courses/#{c.id}/edit"}
        class="btn btn-ghost btn-xs"
      >
        Edit
      </.link>
    </:action>
    <:action :let={c}>
      <.link
        :if={StellarWeb.Perms.can?(@permissions, "courses:manage")}
        href={~p"/courses/#{c.id}"}
        method="delete"
        data-confirm={"Hapus course #{c.title}?"}
        class="btn btn-ghost btn-xs text-error"
      >
        Delete
      </.link>
    </:action>
  </.table>
</Layouts.admin>
```

- [ ] **Step 5: new template**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/course_html/new.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:courses}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>New course</.header>

  <.course_form
    form={@form}
    action={~p"/courses"}
    method="post"
    submit_label="Create"
    superuser={@superuser}
    section_options={@section_options}
    industry_options={@industry_options}
    org_options={@org_options}
    industry_checked={@industry_checked}
    org_checked={@org_checked}
  />
</Layouts.admin>
```

- [ ] **Step 6: edit template (materials panel added in Task 3)**

Create `apps/stellar_web/lib/stellar_web/controllers/admin/course_html/edit.html.heex`:

```heex
<Layouts.admin
  flash={@flash}
  active={:courses}
  current_user={@current_user}
  permissions={@permissions}
  active_organization_id={@active_organization_id}
  member_orgs={@member_orgs}
>
  <.header>
    Edit course
    <:subtitle>{@course.title}</:subtitle>
  </.header>

  <.course_form
    form={@form}
    action={~p"/courses/#{@course.id}"}
    method="put"
    submit_label="Save"
    superuser={@superuser}
    section_options={@section_options}
    industry_options={@industry_options}
    org_options={@org_options}
    industry_checked={@industry_checked}
    org_checked={@org_checked}
  />
</Layouts.admin>
```

- [ ] **Step 7: Route scope**

In `router.ex`, add a new scope near the memberships/organizations scopes:

```elixir
  scope "/", StellarWeb.Admin do
    pipe_through [:browser, :require_member, :require_courses_read]

    resources "/courses", CourseController, except: [:show]
  end
```

- [ ] **Step 8: Sidebar entry**

In `layouts.ex` `admin_nav/0`, add after the `:sections` entry:

```elixir
      %{
        key: :courses,
        label: "Courses",
        path: "/courses",
        icon: "hero-academic-cap",
        permission: "courses:read"
      },
```

- [ ] **Step 9: Verify**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 10: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(web): course admin (per-tenant CRUD + industries + sharing)"
```

---

### Task 3: Course materials panel

**Files:**
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/course_controller.ex` (edit assigns + `add_material`/`link_material`/`detach_material` actions)
- Modify: `apps/stellar_web/lib/stellar_web/controllers/admin/course_html/edit.html.heex` (materials panel)
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (3 material routes)

**Interfaces:**
- Consumes: `StellarDoc.Documents.Document`, active org, `courses:manage`.
- Produces: `POST /courses/:id/materials` (add new), `POST /courses/:id/materials/link` (link existing), `DELETE /courses/:id/materials/:doc_id` (detach).

- [ ] **Step 1: Extend `edit` to load materials + linkable docs + material form**

In `course_controller.ex`, replace the `edit/2` function with:

```elixir
  def edit(conn, %{"id" => id}) do
    if editable?(conn, id) do
      course = Ash.get!(Course, id, authorize?: false)

      render(
        conn,
        :edit,
        [
          course: course,
          form: to_form(update_form(course)),
          materials: materials(id),
          linkable: linkable_docs(conn, id),
          material_form: to_form(material_create_form())
        ] ++ opts(conn, course_industry_ids(id), course_org_ids(id))
      )
    else
      forbid(conn)
    end
  end
```

Add these helpers (near `detach_materials/1`):

```elixir
  alias StellarDoc.Documents.Document

  defp materials(course_id) do
    Document
    |> Ash.Query.filter(course_id == ^course_id)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  # Dokumen bank milik org aktif yang belum tertaut ke course mana pun.
  defp linkable_docs(conn, _course_id) do
    Document
    |> Ash.Query.filter(organization_id == ^active_org(conn) and is_nil(course_id))
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  defp material_create_form,
    do: AshPhoenix.Form.for_create(Document, :create, as: "document", authorize?: false)
```

> Note: `alias StellarDoc.Documents.Document` may already be implied — if the module top already aliases it (from Task 2 Step 2 `detach_materials`), do NOT add a duplicate `alias`. In Task 2 `detach_materials/1` used the fully-qualified name; keep it fully-qualified OR add the single alias here and update `detach_materials/1` to use `Document`. Use exactly one alias.

- [ ] **Step 2: Material actions**

Add to `course_controller.ex`:

```elixir
  def add_material(conn, %{"id" => id, "document" => params}) do
    if editable?(conn, id) do
      attrs =
        params
        |> Map.put("course_id", id)
        |> Map.put("organization_id", active_org(conn))
        |> Map.put("user_id", conn.assigns.current_user.id)

      case AshPhoenix.Form.submit(material_create_form(), params: attrs) do
        {:ok, _doc} ->
          conn |> put_flash(:info, "Materi ditambahkan.") |> redirect(to: ~p"/courses/#{id}/edit")

        {:error, _form} ->
          conn
          |> put_flash(:error, "Gagal menambah materi (cek judul & URL).")
          |> redirect(to: ~p"/courses/#{id}/edit")
      end
    else
      forbid(conn)
    end
  end

  def link_material(conn, %{"id" => id, "document_id" => doc_id}) do
    if editable?(conn, id) do
      Document
      |> Ash.get!(doc_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, %{course_id: id})
      |> Ash.update!(authorize?: false)

      conn |> put_flash(:info, "Dokumen ditautkan sebagai materi.") |> redirect(to: ~p"/courses/#{id}/edit")
    else
      forbid(conn)
    end
  end

  def detach_material(conn, %{"id" => id, "doc_id" => doc_id}) do
    if editable?(conn, id) do
      Document
      |> Ash.get!(doc_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, %{course_id: nil})
      |> Ash.update!(authorize?: false)

      conn |> put_flash(:info, "Materi dilepas.") |> redirect(to: ~p"/courses/#{id}/edit")
    else
      forbid(conn)
    end
  end
```

- [ ] **Step 3: Routes**

In `router.ex`, inside the `:require_courses_read` scope (same block as the course resources), add:

```elixir
    post "/courses/:id/materials", CourseController, :add_material
    post "/courses/:id/materials/link", CourseController, :link_material
    delete "/courses/:id/materials/:doc_id", CourseController, :detach_material
```

- [ ] **Step 4: Materials panel in edit template**

Append to `course_html/edit.html.heex` (below the `<.course_form ... />`, before `</Layouts.admin>`):

```heex
  <div class="divider"></div>

  <section class="space-y-4">
    <h2 class="text-lg font-semibold">Materi kursus</h2>

    <.table id="materials" rows={@materials}>
      <:col :let={m} label="Judul">{m.title}</:col>
      <:col :let={m} label="Tipe">{m.mime_type}</:col>
      <:col :let={m} label="URL">
        <a href={m.url} target="_blank" class="link">{m.url}</a>
      </:col>
      <:action :let={m}>
        <.link
          href={~p"/courses/#{@course.id}/materials/#{m.id}"}
          method="delete"
          data-confirm="Lepas materi ini dari course?"
          class="btn btn-ghost btn-xs text-error"
        >
          Lepas
        </.link>
      </:action>
    </.table>

    <div class="grid gap-6 md:grid-cols-2">
      <div>
        <h3 class="mb-2 font-medium">Tambah materi baru</h3>
        <.form for={@material_form} action={~p"/courses/#{@course.id}/materials"} method="post" class="space-y-3">
          <.input field={@material_form[:title]} type="text" label="Judul" required />
          <.input field={@material_form[:url]} type="text" label="URL" required />
          <.input field={@material_form[:mime_type]} type="text" label="Tipe (mime)" />
          <.input field={@material_form[:description]} type="textarea" label="Deskripsi" rows="2" />
          <.button variant="primary">Tambah</.button>
        </.form>
      </div>

      <div>
        <h3 class="mb-2 font-medium">Tautkan dokumen bank</h3>
        <form
          :if={@linkable != []}
          action={~p"/courses/#{@course.id}/materials/link"}
          method="post"
          class="flex items-end gap-2"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <select name="document_id" class="select select-bordered select-sm">
            <option :for={d <- @linkable} value={d.id}>{d.title}</option>
          </select>
          <button class="btn btn-sm btn-primary">Tautkan</button>
        </form>
        <p :if={@linkable == []} class="text-sm opacity-70">
          Tak ada dokumen org yang belum tertaut.
        </p>
      </div>
    </div>
  </section>
```

- [ ] **Step 5: Verify**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 6: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(web): course materials panel (add/link/detach documents)"
```

---

### Task 4: Cleanup + final verification

**Files:**
- Remove: empty dirs `apps/stellar_web/lib/stellar_web/controllers/admin/{course_html,class_html,material_html}` (only if they exist and are empty; the new `course_html/` from Task 2 is NOT empty — do this check BEFORE Task 2, or skip `course_html`). See Step 1.

- [ ] **Step 1: Remove leftover empty dirs**

The discarded work left empty `class_html/` and `material_html/` (and previously `course_html/`, now repopulated by Task 2). Remove only the still-empty ones:

```bash
rmdir apps/stellar_web/lib/stellar_web/controllers/admin/class_html \
      apps/stellar_web/lib/stellar_web/controllers/admin/material_html 2>/dev/null || true
```

(`rmdir` fails harmlessly if non-empty/absent. Do NOT remove `course_html` — Task 2 fills it.)

- [ ] **Step 2: Final compile + format**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: clean.

- [ ] **Step 3: Manual smoke checklist (USER, after `mix phx.server`)**
  - As superuser: `/sections` create/edit/delete a section; `/courses` create a course (pick section, industries, share to ≥1 tenant); in course edit, add a material + link an existing bank doc + detach one.
  - As a `coordinator`/`teacher` (non-superuser): `/courses` shows only courses linked to the active org; creating a course auto-links it to the active org; `/sections` is not in the sidebar and `/sections` redirects away.
  - RAG page course dropdown now lists the created courses.

- [ ] **Step 4: Commit (USER runs git — do not execute)**

```bash
git add -A
git commit -m "chore(web): cleanup leftover template dirs; catalog admin complete"
```

---

## Post-plan handoff (not steps)
- **Git:** all commits are the user's.
- **No migrations** in this spec (no schema changes).
- **Next spec:** Class + Enrollment admin (delivery), instructor materials, then REST/Flutter.
