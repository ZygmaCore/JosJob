# Catalog Admin (Section + Course) — Design

**Status:** approved design, ready for implementation plan
**Scope:** admin web UI + RBAC gating for the **catalog** layer of the course
ecosystem — `Section` (superuser master-data) and `Course` (per-tenant), including
course↔industry (M:N), course↔organization sharing, and attaching course materials
(documents). Built in `apps/josjob_web` following the existing controller+HTML+sidebar
pattern (Organizations/Industries).

Depends on the course-ecosystem domain (`JosjobLrn.Learning`, already built).

---

## 1. Surfaces

### 1.1 Section admin — superuser only
- Lives under the `require_admin` pipeline (superuser), like `IndustryController`.
  **No new permission key.**
- CRUD on `JosjobLrn.Learning.Section`: fields `name` (required), `description`,
  `is_active` (default true).
- Sidebar entry "Sections" with `visible: :superuser`.
- Routes: `resources "/sections", Admin.SectionController, except: [:show]` in the
  superuser admin scope (`pipe_through [:browser, :require_admin]`).

### 1.2 Course admin — per-tenant via `courses:*`
- Route gated by `courses:read`; `create`/`edit`/`update`/`delete` gated by
  `courses:manage`. Both permission keys already exist (category "learning";
  held by `coordinator` + `teacher`). **No new permission key.**
- Controller mirrors `OrganizationController` helpers: `su?/1`, `can_manage?/1`,
  `active_org/1`, `forbid/1`, `base_scope/1`.
- Sidebar entry "Courses" with `permission: "courses:read"`.
- Routes: `resources "/courses", Admin.CourseController` (index/new/create/edit/update/delete)
  in a scope `pipe_through [:browser, :require_member, :require_courses_read]`
  (new pipeline mirroring `:require_orgs_read`). Per-action `courses:manage` checks
  happen inside the controller (as OrganizationController does with `organizations:manage`).

---

## 2. RBAC & scoping (Course)

- **Index:** superuser → all courses; non-superuser → courses linked to the **active org**
  via `course_organizations` (`Ash.Query.filter(Course, organizations.id == ^active_org)`).
- **Create:**
  - Common fields: `section_id` (dropdown of **all active sections** — `section_organizations`
    is ignored in this spec), `title`, `description`, `is_active`, `industries` (multi-select →
    `course_industries`).
  - **Tenant sharing:** superuser → multi-select `organizations` (writes `course_organizations`
    rows). Non-superuser → the course is auto-linked to the active org only (no org picker).
- **Edit/Update/Delete:** allowed when `can_manage?` and (superuser OR the course is linked to
  the active org). Non-superuser cannot change the org links (their course stays theirs);
  superuser can re-share.
- **Delete:** first detach materials (`UPDATE documents SET course_id = NULL WHERE course_id = ?`
  via Ash), then destroy the course (join rows `course_organizations`/`course_industries` drop
  via their FK `on_delete: :delete`).

---

## 3. Course materials panel

On the Course edit page, a "Materi" panel operating on `JosjobDoc.Documents.Document`:

- **List:** documents where `course_id == course.id` (the course's materials).
- **Add new:** form (`title`, `url`, `mime_type`, `description`) → creates a Document with
  `course_id = course.id`, `organization_id = active_org`, `user_id = current_user.id`.
- **Link existing:** pick from the active org's unlinked documents
  (`organization_id == active_org AND course_id IS NULL`) → set their `course_id = course.id`.
- **Detach:** set a document's `course_id = NULL` (it returns to the plain bank; not deleted).

All document reads/writes go through `JosjobDoc.Documents` / Ash with `authorize?: false`
(web-layer enforcement, consistent with the rest of the app). `josjob_web` already depends on
`:josjob_doc` and `:josjob_lrn`.

---

## 4. Files (indicative)

- Create: `apps/josjob_web/lib/josjob_web/controllers/admin/section_controller.ex` + `section_html.ex` + `section_html/{index,new,edit,section_form}.html.heex`
- Create: `apps/josjob_web/lib/josjob_web/controllers/admin/course_controller.ex` + `course_html.ex` + `course_html/{index,new,edit,course_form}.html.heex` (edit template includes the materials panel)
- Modify: `apps/josjob_web/lib/josjob_web/router.ex` (new `:require_courses_read` pipeline + section/course scopes)
- Modify: `apps/josjob_web/lib/josjob_web/components/layouts.ex` (sidebar entries "Sections" superuser, "Courses" permission `courses:read`)
- Remove: empty leftover dirs `apps/josjob_web/lib/josjob_web/controllers/admin/{course_html,class_html,material_html}` (dead, from the discarded work)

---

## 5. Out of scope (future specs)
- `Class` + `Enrollment` admin (delivery layer) — next spec.
- Instructor materials management.
- `section_organizations` management (section sharing per tenant) — deferred; all active
  sections are globally selectable for now.
- REST/Flutter student-facing flows.

---

## 6. Verification
- `mix compile --warnings-as-errors` and `mix format --check-formatted` clean.
- Temporary controller conn-tests on the TEST DB (via `JosjobWeb.ConnCase` + existing auth
  helpers), removed after they pass:
  - superuser sees all courses; a `coordinator` sees only courses linked to their active org;
  - a non-superuser `create` auto-links the course to the active org (a `course_organizations`
    row appears) and cannot see another org's course;
  - adding a material sets `documents.course_id`; detaching sets it back to `NULL`;
  - Section routes are superuser-only (a non-superuser is redirected).
- **Do not** run migrations/seed against the dev DB (none are needed for this spec — no schema
  changes). **Do not** run git — the user commits.
