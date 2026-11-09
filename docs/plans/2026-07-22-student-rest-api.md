# Student REST API (Catalog + Enrollment) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bearer-authenticated, org-scoped student API — browse catalog, view course detail (classes + materials), self-enroll/unenroll, list own enrollments — plus API docs.

**Architecture:** Two JSON controllers in `apps/stellar_web` (pattern: `StellarWeb.Api.IndustryController`), a shared org-scope helper, and one domain helper `Learning.seats_left/1`. Enroll/unenroll go through the existing `Enrollment` actions (capacity + unique enforced in the domain); the controller pre-checks to return deterministic `409`s. No schema changes.

**Tech Stack:** Phoenix 1.8 controllers (JSON), Ash 3, `:api_auth` Bearer plug.

## Global Constraints

- **NEVER run git.** Commit steps are FYI checkpoints.
- **No schema changes / no migrations.** TEST DB only for verification.
- All endpoints under the existing `:api_auth` pipeline (`conn.assigns.current_user`).
- Responses use the `{ "data": … }` envelope; errors `{ "error": "<code>" }` with an HTTP status.
- DRY/YAGNI. Reuse `StellarLrn.Learning.materials_for_class/1`.
- Verify: `mix compile --warnings-as-errors` + `mix format --check-formatted` clean; temporary request-tests on the TEST DB (removed after). Then the doc task.

---

### Task 1: `Learning.seats_left/1` (domain helper)

**Files:**
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning.ex`

**Interfaces:**
- Produces: `StellarLrn.Learning.seats_left(class_or_id)` → `nil` (unlimited) | non-neg integer.

- [ ] **Step 1: Add alias + function**

In `apps/stellar_lrn/lib/stellar_lrn/learning.ex`, add `Enrollment` to the alias line:

```elixir
  alias StellarLrn.Learning.{Section, Course, Class, Enrollment}
```

Add these functions (after `materials_for_class/…`, before the tenant helpers):

```elixir
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

    max(capacity - active, 0)
  end
```

- [ ] **Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: clean.

- [ ] **Step 3: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn
git commit -m "feat(lrn): Learning.seats_left/1"
```

---

### Task 2: Catalog API (`CatalogController`) + shared org-scope helper

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/api/student_scope.ex`
- Create: `apps/stellar_web/lib/stellar_web/controllers/api/catalog_controller.ex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (catalog routes under `:api_auth`)

**Interfaces:**
- Produces: `StellarWeb.Api.StudentScope.org_ids/1`; `GET /api/catalog/courses`, `GET /api/catalog/courses/:id`.
- Consumes: `StellarLrn.Learning.{Course, Class}`, `StellarLrn.Learning.{seats_left/1, materials_for_class/1}`, `StellarDoc.Documents.Document`, `StellarLrn.Learning.Enrollment`.

- [ ] **Step 1: Shared org-scope helper**

Create `apps/stellar_web/lib/stellar_web/controllers/api/student_scope.ex`:

```elixir
defmodule StellarWeb.Api.StudentScope do
  @moduledoc "Org ids tempat user jadi member aktif (scoping API student)."
  require Ash.Query
  alias Stellar.Orgs.Membership

  def org_ids(user) do
    Membership
    |> Ash.Query.filter(user_id == ^user.id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.organization_id)
    |> Enum.uniq()
  end
end
```

- [ ] **Step 2: Catalog controller**

Create `apps/stellar_web/lib/stellar_web/controllers/api/catalog_controller.ex`:

```elixir
defmodule StellarWeb.Api.CatalogController do
  @moduledoc """
  Katalog student (Bearer). Course aktif yang dibagikan ke org tempat user jadi
  member. Detail menyertakan kelas (di org user) + materi.
  """
  use StellarWeb, :controller

  require Ash.Query

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Course, Class, Enrollment}
  alias StellarDoc.Documents.Document
  alias StellarWeb.Api.StudentScope

  # GET /api/catalog/courses
  def index(conn, _params) do
    org_ids = StudentScope.org_ids(conn.assigns.current_user)

    courses =
      Course
      |> Ash.Query.filter(is_active == true and organizations.id in ^org_ids)
      |> Ash.Query.sort(title: :asc)
      |> Ash.Query.load([:section, :industries, :classes])
      |> Ash.read!(authorize?: false)

    json(conn, %{data: Enum.map(courses, &course_summary_json(&1, org_ids))})
  end

  # GET /api/catalog/courses/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    org_ids = StudentScope.org_ids(user)

    course =
      Course
      |> Ash.Query.filter(id == ^id and is_active == true and organizations.id in ^org_ids)
      |> Ash.Query.load([:section, :industries])
      |> Ash.read_one!(authorize?: false)

    case course do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      course ->
        classes =
          Class
          |> Ash.Query.filter(course_id == ^course.id and organization_id in ^org_ids)
          |> Ash.Query.sort(created_at: :asc)
          |> Ash.Query.load([:instructor])
          |> Ash.read!(authorize?: false)

        json(conn, %{data: course_detail_json(course, classes, user)})
    end
  end

  # --- JSON builders ---

  defp course_summary_json(course, org_ids) do
    class_count = Enum.count(course.classes, &(&1.organization_id in org_ids))

    %{
      id: course.id,
      title: course.title,
      description: course.description,
      section: section_json(course.section),
      industries: Enum.map(course.industries, &%{id: &1.id, name: &1.name}),
      class_count: class_count
    }
  end

  defp course_detail_json(course, classes, user) do
    %{
      id: course.id,
      title: course.title,
      description: course.description,
      section: section_json(course.section),
      industries: Enum.map(course.industries, &%{id: &1.id, name: &1.name}),
      materials: course.id |> course_materials() |> Enum.map(&material_json/1),
      classes: Enum.map(classes, &class_json(&1, user))
    }
  end

  defp section_json(nil), do: nil
  defp section_json(s), do: %{id: s.id, name: s.name}

  defp class_json(class, user) do
    %{
      id: class.id,
      title: class.title,
      schedule: class.schedule,
      capacity: class.capacity,
      seats_left: Learning.seats_left(class),
      instructor: class.instructor && %{id: class.instructor.id, full_name: class.instructor.full_name},
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
    do: %{id: d.id, title: d.title, url: d.url, mime_type: d.mime_type, description: d.description}

  defp enrolled?(class_id, user_id) do
    Enrollment
    |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end
end
```

- [ ] **Step 3: Routes**

In `router.ex`, inside `scope "/api", StellarWeb.Api do ... end` (after the `payments` scope, before the scope closes), add:

```elixir
    # Katalog student (Bearer).
    scope "/catalog" do
      pipe_through :api_auth

      get "/courses", CatalogController, :index
      get "/courses/:id", CatalogController, :show
    end
```

- [ ] **Step 4: Verify**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 5: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(api): student catalog endpoints"
```

---

### Task 3: Enrollment API (`EnrollmentController`)

**Files:**
- Create: `apps/stellar_web/lib/stellar_web/controllers/api/enrollment_controller.ex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (enroll/unenroll/my routes)

**Interfaces:**
- Produces: `POST /api/classes/:id/enroll`, `DELETE /api/classes/:id/enroll`, `GET /api/me/enrollments`.

- [ ] **Step 1: Controller**

Create `apps/stellar_web/lib/stellar_web/controllers/api/enrollment_controller.ex`:

```elixir
defmodule StellarWeb.Api.EnrollmentController do
  @moduledoc """
  Enrollment student (Bearer). Enroll/unenroll ke kelas di org tempat user member.
  Kapasitas & dobel diperiksa eksplisit (409) + backstop domain.
  """
  use StellarWeb, :controller

  require Ash.Query

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Class, Enrollment}
  alias StellarWeb.Api.StudentScope

  # POST /api/classes/:id/enroll
  def create(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    with {:ok, _class} <- visible_class(conn, class_id),
         :ok <- not_already_enrolled(class_id, user.id),
         :ok <- has_seat(class_id) do
      case Ash.Changeset.for_create(Enrollment, :create, %{class_id: class_id, student_id: user.id})
           |> Ash.create(authorize?: false) do
        {:ok, enr} ->
          conn
          |> put_status(:created)
          |> json(%{data: %{enrollment_id: enr.id, class_id: class_id, status: enr.status}})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid"})
      end
    end
  end

  # DELETE /api/classes/:id/enroll
  def delete(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    enrollment =
      Enrollment
      |> Ash.Query.filter(class_id == ^class_id and student_id == ^user.id)
      |> Ash.read!(authorize?: false)
      |> List.first()

    case enrollment do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_enrolled"})

      enr ->
        Ash.destroy!(enr, authorize?: false)
        json(conn, %{data: %{ok: true}})
    end
  end

  # GET /api/me/enrollments
  def index(conn, _params) do
    user = conn.assigns.current_user

    enrollments =
      Enrollment
      |> Ash.Query.filter(student_id == ^user.id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.load(class: [:course])
      |> Ash.read!(authorize?: false)

    json(conn, %{data: Enum.map(enrollments, &enrollment_json/1)})
  end

  # --- guards (return {:error-rendered conn} via `else` in `with`) ---

  defp visible_class(conn, class_id) do
    org_ids = StudentScope.org_ids(conn.assigns.current_user)

    case Ash.get(Class, class_id, authorize?: false) do
      {:ok, %Class{organization_id: org_id} = class} ->
        if org_id in org_ids, do: {:ok, class}, else: {:halt, not_found(conn)}

      _ ->
        {:halt, not_found(conn)}
    end
  end

  defp not_already_enrolled(class_id, user_id) do
    exists? =
      Enrollment
      |> Ash.Query.filter(class_id == ^class_id and student_id == ^user_id)
      |> Ash.read!(authorize?: false)
      |> Enum.any?()

    if exists?, do: {:halt, :already_enrolled}, else: :ok
  end

  defp has_seat(class_id) do
    case Learning.seats_left(class_id) do
      nil -> :ok
      n when n > 0 -> :ok
      _ -> {:halt, :full}
    end
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp enrollment_json(e) do
    %{
      id: e.id,
      status: e.status,
      enrolled_at: e.enrolled_at,
      class:
        e.class &&
          %{
            id: e.class.id,
            title: e.class.title,
            schedule: e.class.schedule,
            course: e.class.course && %{id: e.class.course.id, title: e.class.course.title}
          }
    }
  end
end
```

> **Note on `with` control flow:** the guards return `{:halt, conn}` (already-rendered
> `not_found`) or `{:halt, :already_enrolled}` / `{:halt, :full}` atoms. Add an `else`
> clause to `create/2`'s `with` to render those:
>
> ```elixir
>     else
>       {:halt, %Plug.Conn{} = conn} -> conn
>       {:halt, :already_enrolled} -> conn |> put_status(:conflict) |> json(%{error: "already_enrolled"})
>       {:halt, :full} -> conn |> put_status(:conflict) |> json(%{error: "full"})
>     end
> ```
>
> Place this `else` on the `with` in `create/2` (the `with ... do ... else ... end`).
> The `conn` referenced in the `else` for atoms is the controller's `conn` (in scope).

- [ ] **Step 2: Finalize `create/2` with the `else` block**

Ensure `create/2` reads exactly:

```elixir
  def create(conn, %{"id" => class_id}) do
    user = conn.assigns.current_user

    with {:ok, _class} <- visible_class(conn, class_id),
         :ok <- not_already_enrolled(class_id, user.id),
         :ok <- has_seat(class_id) do
      case Ash.Changeset.for_create(Enrollment, :create, %{class_id: class_id, student_id: user.id})
           |> Ash.create(authorize?: false) do
        {:ok, enr} ->
          conn
          |> put_status(:created)
          |> json(%{data: %{enrollment_id: enr.id, class_id: class_id, status: enr.status}})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid"})
      end
    else
      {:halt, %Plug.Conn{} = c} -> c
      {:halt, :already_enrolled} -> conn |> put_status(:conflict) |> json(%{error: "already_enrolled"})
      {:halt, :full} -> conn |> put_status(:conflict) |> json(%{error: "full"})
    end
  end
```

- [ ] **Step 3: Routes**

In `router.ex`, inside `scope "/api", StellarWeb.Api`, after the catalog scope, add:

```elixir
    # Enrollment student (Bearer).
    scope "/" do
      pipe_through :api_auth

      post "/classes/:id/enroll", EnrollmentController, :create
      delete "/classes/:id/enroll", EnrollmentController, :delete
      get "/me/enrollments", EnrollmentController, :index
    end
```

- [ ] **Step 4: Verify**

Run: `mix compile --warnings-as-errors && mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 5: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_web
git commit -m "feat(api): student enroll/unenroll/my-enrollments"
```

---

### Task 4: Temporary request-tests + full verification

**Files:**
- Create (temp): `apps/stellar_web/test/stellar_web/controllers/api/student_api_test.exs`

- [ ] **Step 1: Write the request-test**

Create `apps/stellar_web/test/stellar_web/controllers/api/student_api_test.exs`:

```elixir
defmodule StellarWeb.Api.StudentApiTest do
  use StellarWeb.ConnCase, async: false

  require Ash.Query

  alias StellarLrn.Learning.{Section, Course, CourseOrganization, Class}

  defp user!(attrs \\ %{}) do
    {:ok, u} =
      Stellar.Accounts.User
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(%{email: "s#{System.unique_integer([:positive])}@ex.com", full_name: "S"}, attrs)
      )
      |> Ash.create(authorize?: false)

    u
  end

  defp org!(owner) do
    {:ok, o} =
      Stellar.Orgs.Organization
      |> Ash.Changeset.for_create(:create, %{name: "Org #{System.unique_integer([:positive])}", user_id: owner.id})
      |> Ash.create(authorize?: false)

    o
  end

  defp member!(user, org) do
    {:ok, m} =
      Stellar.Orgs.Membership
      |> Ash.Changeset.for_create(:create, %{user_id: user.id, organization_id: org.id, status: :active})
      |> Ash.create(authorize?: false)

    m
  end

  defp course!(org, attrs \\ %{}) do
    {:ok, section} = Section |> Ash.Changeset.for_create(:create, %{name: "Sec"}) |> Ash.create(authorize?: false)

    {:ok, course} =
      Course
      |> Ash.Changeset.for_create(:create, Map.merge(%{title: "Go", section_id: section.id, is_active: true}, attrs))
      |> Ash.create(authorize?: false)

    {:ok, _} =
      CourseOrganization
      |> Ash.Changeset.for_create(:create, %{course_id: course.id, organization_id: org.id})
      |> Ash.create(authorize?: false)

    course
  end

  defp class!(course, org, instructor, capacity \\ nil) do
    {:ok, class} =
      Class
      |> Ash.Changeset.for_create(:create, %{
        course_id: course.id,
        organization_id: org.id,
        instructor_id: instructor.id,
        capacity: capacity
      })
      |> Ash.create(authorize?: false)

    class
  end

  defp auth(conn, user) do
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  setup %{conn: conn} do
    student = user!()
    org = org!(student)
    member!(student, org)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), student: student, org: org}
  end

  test "401 without token", %{conn: conn} do
    assert conn |> get(~p"/api/catalog/courses") |> json_response(401)
  end

  test "catalog lists only active courses in the user's org", %{conn: conn, student: student, org: org} do
    course!(org)
    other_owner = user!()
    other_org = org!(other_owner)
    course!(other_org, %{title: "Hidden"})

    body = conn |> auth(student) |> get(~p"/api/catalog/courses") |> json_response(200)
    titles = Enum.map(body["data"], & &1["title"])
    assert "Go" in titles
    refute "Hidden" in titles
  end

  test "course detail 404 for a course not in the user's org", %{conn: conn, student: student} do
    other = user!()
    other_org = org!(other)
    course = course!(other_org)

    assert conn |> auth(student) |> get(~p"/api/catalog/courses/#{course.id}") |> json_response(404)
  end

  test "enroll success, duplicate 409, capacity 409", %{conn: conn, student: student, org: org} do
    instructor = user!()
    course = course!(org)
    class = class!(course, org, instructor, 1)

    ok = conn |> auth(student) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(201)
    assert ok["data"]["status"] in ["active", :active |> to_string()]

    dup = conn |> auth(student) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(409)
    assert dup["error"] == "already_enrolled"

    other = user!()
    member!(other, org)
    full = conn |> auth(other) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(409)
    assert full["error"] == "full"
  end

  test "enroll 404 for a class in a non-member org", %{conn: conn, student: student} do
    ow = user!()
    other_org = org!(ow)
    course = course!(other_org)
    class = class!(course, other_org, ow)

    assert conn |> auth(student) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(404)
  end

  test "unenroll then 404 not_enrolled", %{conn: conn, student: student, org: org} do
    instructor = user!()
    course = course!(org)
    class = class!(course, org, instructor)

    conn |> auth(student) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(201)
    assert conn |> auth(student) |> delete(~p"/api/classes/#{class.id}/enroll") |> json_response(200)
    nf = conn |> auth(student) |> delete(~p"/api/classes/#{class.id}/enroll") |> json_response(404)
    assert nf["error"] == "not_enrolled"
  end

  test "my enrollments", %{conn: conn, student: student, org: org} do
    instructor = user!()
    course = course!(org)
    class = class!(course, org, instructor)
    conn |> auth(student) |> post(~p"/api/classes/#{class.id}/enroll") |> json_response(201)

    body = conn |> auth(student) |> get(~p"/api/me/enrollments") |> json_response(200)
    assert [%{"class" => %{"course" => %{"title" => "Go"}}}] = body["data"]
  end
end
```

- [ ] **Step 2: Run the request-tests**

Run: `cd apps/stellar_web && mix test test/stellar_web/controllers/api/student_api_test.exs && cd ../..`
Expected: all pass. If token minting differs (`token_for_user` returning `:error`), fall back to issuing a token via the password/`sign_in` flow or `Ash.load(user, :token)` — the point is a valid Bearer accepted by `ApiAuth`.

- [ ] **Step 3: Full suite + format**

Run: `mix test && mix format --check-formatted`
Expected: all pass, format clean.

- [ ] **Step 4: Remove the temp test (project norm)**

Run: `rm -f apps/stellar_web/test/stellar_web/controllers/api/student_api_test.exs`

- [ ] **Step 5: Re-verify**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: clean.

- [ ] **Step 6: Commit (USER runs git — do not execute)**

```bash
git add -A
git commit -m "chore(api): student REST API verified"
```

---

### Task 5: API documentation (`docs/api/`)

**Files:**
- Create: `docs/api/learning.md`
- Delete: `docs/api/vod.md` (documents the now-removed VOD API — stale/misleading)

- [ ] **Step 1: Write `docs/api/learning.md`**

Create `docs/api/learning.md` matching the style of `docs/api/auth.md` (base URL, Bearer
note, one section per endpoint with method/path/auth/params + request/response JSON +
error codes). Content:

```markdown
# Learning API Contract (Catalog + Enrollment)

Student-facing endpoints for browsing the course catalog and managing enrollments.

- **Base URL** (local dev): `http://localhost:4000`
- All requests/responses are JSON; successful bodies use a `{ "data": … }` envelope,
  errors use `{ "error": "<code>" }`.
- **All endpoints require** `Authorization: Bearer <access_token>` (the JWT from
  [`auth.md`](./auth.md), pipeline `:api_auth`). Missing/invalid → `401 {"error":"unauthorized"}`.
- Data is **org-scoped**: a user sees courses/classes only for organizations where they
  are an active member.

---

## GET /api/catalog/courses
Active courses shared to the user's organizations.

**Response 200**
{ "data": [ { "id", "title", "description",
  "section": {"id","name"},
  "industries": [{"id","name"}],
  "class_count": 2 } ] }

## GET /api/catalog/courses/:id
Course detail with classes (in the user's orgs) and materials.
`404 {"error":"not_found"}` if not visible to the user.

**Response 200**
{ "data": { "id","title","description",
  "section": {"id","name"},
  "industries": [{"id","name"}],
  "materials": [{"id","title","url","mime_type","description"}],
  "classes": [ { "id","title","schedule": [ ... ],
    "capacity": 10, "seats_left": 7,
    "instructor": {"id","full_name"},
    "enrolled": false,
    "materials": [{"id","title","url","mime_type"}] } ] } }

- `seats_left` is `null` when capacity is unlimited, else `capacity − active enrollments`.
- `enrolled` = whether the current user is enrolled in that class.

## POST /api/classes/:id/enroll
Enroll the current user into a class.

- **201** `{ "data": { "enrollment_id", "class_id", "status": "active" } }`
- **404** `{"error":"not_found"}` — class missing or not in the user's orgs.
- **409** `{"error":"already_enrolled"}` — user already enrolled.
- **409** `{"error":"full"}` — class at capacity.

## DELETE /api/classes/:id/enroll
Remove the current user's enrollment for a class.

- **200** `{ "data": { "ok": true } }`
- **404** `{"error":"not_enrolled"}`

## GET /api/me/enrollments
The current user's enrollments.

**Response 200**
{ "data": [ { "id","status","enrolled_at",
  "class": { "id","title","schedule": [ ... ],
    "course": {"id","title"} } } ] }
```

(Render the JSON blocks as fenced ```json``` code blocks, matching `auth.md`/`vod.md`.)

- [ ] **Step 2: Remove stale VOD doc**

Run: `rm -f docs/api/vod.md`
(The VOD API was removed earlier this session; its contract doc is now misleading.)

- [ ] **Step 3: Commit (USER runs git — do not execute)**

```bash
git add docs/api
git commit -m "docs(api): learning catalog+enrollment contract; drop stale vod.md"
```

---

## Post-plan handoff (not steps)
- **Git:** all commits are the user's. **No migrations.**
- This completes the course-ecosystem arc: domain → catalog admin → delivery admin → student API + docs.
