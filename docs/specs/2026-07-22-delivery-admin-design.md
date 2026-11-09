# Delivery Admin (Class + Enrollment) — Design

**Status:** approved design, ready for implementation plan
**Scope:** admin web UI + RBAC gating for the **delivery** layer — `Class` CRUD
(instructor + schedule + capacity), full `Enrollment` management, and a read-only
view of a class's effective materials. Built in `apps/stellar_web` following the
catalog-admin pattern (`CourseController`). No schema changes.

Depends on: `StellarLrn.Learning` domain (built), catalog admin (Section/Course, built),
`StellarDoc.Documents`.

---

## 1. Class admin (`ClassController` + `ClassHTML`)

- Route under a scope `pipe_through [:browser, :require_member, :require_courses_read]`
  (reuse the existing `:require_courses_read` pipeline). Per-action `courses:manage`
  checks inside the controller (mirrors `CourseController`). Sidebar entry "Classes"
  with `permission: "courses:read"`.
- Controller helpers mirror `CourseController`: `su?/1`, `can_manage?/1`, `active_org/1`,
  `forbid/1`, `base_scope/1`, `editable?/2`.

### 1.1 Scoping
- **Index:** superuser → all classes; non-superuser → `Ash.Query.filter(Class, organization_id == ^active_org)`.
- **Edit/Update/Delete:** `can_manage?` and (superuser OR `class.organization_id == active_org`).

### 1.2 Form fields
- `course_id` (select), `instructor_id` (select), `title` (optional), `capacity`
  (integer; blank → `nil` = unlimited).
- `organization_id`:
  - **non-superuser:** forced to `active_org` (hidden field / set server-side).
    Course options = courses linked to active org (`course_organizations`);
    instructor options = active-org members (via `Stellar.Orgs.Membership`).
  - **superuser:** an `organization` select (all orgs). Course options = all courses;
    instructor options = all users. (Static dropdowns — no cross-field filtering.)
- `schedule` — **dynamic add/remove rows** (small inline vanilla JS in the template).
  Each row: `start_date` + `end_date` (`<input type="datetime-local">`) + a `recurring`
  checkbox. Item shape stored in the `{:array, :map}` jsonb:
  ```json
  [{ "start_date": "2024-06-19T00:00:00Z", "end_date": "2024-06-19T23:59:59Z", "recurring": false }]
  ```
  The domain does **not** interpret `schedule`/`recurring` (stored as-is, consistent with
  the domain spec). The controller parses the submitted rows into this list before
  building the changeset.

### 1.3 Schedule parsing (controller)
Inputs named `class[schedule][<i>][start_date|end_date|recurring]`. Phoenix delivers
`params["class"]["schedule"]` as an index-keyed map; the controller does
`Map.values/1`, drops blank rows (no `start_date`), coerces `recurring` (`"true"/"on" → true`,
else `false`), and passes the resulting list as the `schedule` attribute. On validation
error the submitted rows are re-rendered.

### 1.4 Delete
`Ash.destroy` the class; `enrollments` drop via FK `on_delete: :delete`.

---

## 2. Enrollment management (on the Class edit page)

Full management, gated by the same `editable?/2` as the class:

- **List:** enrollments for the class (student name, `status`, `enrolled_at`).
- **Add student:** select from active-org members **not already enrolled** →
  `Enrollment` `:create` with `class_id` + `student_id`. Capacity is enforced by the
  existing `StellarLrn.Learning.Changes.CheckCapacity`; the unique `(class_id, student_id)`
  identity rejects duplicates. On `{:error, _}` show a flash (e.g. "kelas penuh / sudah terdaftar").
- **Remove:** `Ash.destroy` the enrollment.
- **Set status:** update `status` between `:active` and `:completed`.

### 2.1 Enrollment resource change (no migration)
The `Enrollment` resource must allow updating `status`. Add either
`default_accept [:status]` or a dedicated update action `:set_status` accepting `:status`.
This is a code-only change (the column already exists).

### 2.2 Routes
```
post   "/classes/:id/enrollments",          ClassController, :add_enrollment
delete "/classes/:id/enrollments/:enr_id",  ClassController, :remove_enrollment
patch  "/classes/:id/enrollments/:enr_id",  ClassController, :set_enrollment_status
```
All redirect back to `~p"/classes/#{id}/edit"`.

---

## 3. Effective materials (read-only, on the Class edit page)

Show `StellarLrn.Learning.materials_for_class(class)` — the union of course materials
(`documents.course_id == class.course_id`) and instructor materials
(`documents.user_id == class.instructor_id AND course_id IS NULL`) — as a read-only list
(title, mime_type, url). Instructor materials are **managed via the existing
`/my/documents` portal**, not here.

---

## 4. Files (indicative)

- Create: `apps/stellar_web/lib/stellar_web/controllers/admin/class_controller.ex` + `class_html.ex` + `class_html/{index,new,edit}.html.heex`
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (class scope + enrollment routes)
- Modify: `apps/stellar_web/lib/stellar_web/components/layouts.ex` (sidebar "Classes")
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning/enrollment.ex` (allow `status` update)

---

## 5. Out of scope (future)
- REST/Flutter student-facing flows (self-enroll, browse).
- `section_organizations` management.
- Notifications / schedule-conflict validation / recurring expansion.

---

## 6. Verification
- `mix compile --warnings-as-errors` and `mix format --check-formatted` clean.
- Runtime sanity-check on the TEST DB (throwaway `mix run -e`, not committed): the class
  base-scope filter, the "active-org members not yet enrolled" query, and
  `materials_for_class/1` run without error; a capacity-limited `Enrollment` create is
  rejected when full and a status update succeeds.
- Manual smoke test by the user (`mix phx.server`): create a class (schedule rows +
  capacity), enroll/remove/complete students, confirm capacity + duplicate rejection,
  confirm effective materials show; verify non-superuser sees only their org's classes.
- **No migrations** (no schema changes). **No git** — the user commits.
