# Student REST API (Catalog + Enrollment) — Design

**Status:** approved design, ready for implementation plan
**Scope:** student-facing JSON API in `apps/josjob_web` — browse the course catalog,
view course detail (classes + materials), self-enroll / unenroll, and list own
enrollments. All endpoints are Bearer-authenticated and org-scoped.

**Not in scope:** wiring the Flutter app (`josjob_fe` is UI-only per CLAUDE.md — no
backend calls), paid access/payments, notifications, advanced pagination/filtering.

Depends on: `JosjobLrn.Learning` domain, `JosjobDoc.Documents`, `Josjob.Orgs.Membership`,
existing `:api_auth` plug (`JosjobWeb.Plugs.ApiAuth` → `conn.assigns.current_user`).

---

## 1. Placement & auth

- Controllers: `JosjobWeb.Api.CatalogController`, `JosjobWeb.Api.EnrollmentController`
  (pattern: `use JosjobWeb, :controller`, respond `json(conn, %{data: ...})`, mirroring
  `JosjobWeb.Api.IndustryController`).
- All routes under the existing `:api_auth` pipeline (Bearer access token). No new pipeline.
- Domain helper: add `JosjobLrn.Learning.seats_left/1`.

### Visibility rule
`user_org_ids(user)` = org ids of the user's **active** memberships
(`Josjob.Orgs.Membership` where `user_id == user.id and status == :active`).
- A **course** is visible when `is_active == true` AND it is linked (via
  `course_organizations`) to at least one of the user's orgs.
- A **class** is visible / enrollable when its `organization_id` ∈ `user_org_ids`.

---

## 2. Endpoints

All require a valid Bearer token (else `401` from `ApiAuth`). `:current_user` is the student.

### GET `/api/catalog/courses`
Active courses shared to the user's orgs.
```json
{ "data": [
  { "id": "…", "title": "Go Programming", "description": "…",
    "section": { "id": "…", "name": "Technology Information" },
    "industries": [ { "id": "…", "name": "Software & IT" } ],
    "class_count": 2 }
] }
```

### GET `/api/catalog/courses/:id`
`404 {"error":"not_found"}` when the course is not visible to the user.
```json
{ "data": {
  "id": "…", "title": "…", "description": "…",
  "section": { "id": "…", "name": "…" },
  "industries": [ { "id": "…", "name": "…" } ],
  "materials": [ { "id": "…", "title": "…", "url": "…", "mime_type": "…", "description": "…" } ],
  "classes": [
    { "id": "…", "title": "…", "schedule": [ … ],
      "capacity": 10, "seats_left": 7,
      "instructor": { "id": "…", "full_name": "…" },
      "enrolled": false,
      "materials": [ { "id": "…", "title": "…", "url": "…", "mime_type": "…" } ] }
  ]
} }
```
- `classes` = classes of this course whose `organization_id` ∈ user orgs.
- `materials` (course) = documents where `course_id == course.id`.
- per-class `materials` = `JosjobLrn.Learning.materials_for_class(class)`.
- `enrolled` = current user has an enrollment in that class.

### POST `/api/classes/:id/enroll`
Enrolls `current_user` into the class.
- `404` when the class is not visible (`organization_id` not in user orgs) or missing.
- On success: `201 { "data": { "enrollment_id": "…", "class_id": "…", "status": "active" } }`.
- Domain rejects (via `Enrollment.:create` → `CheckCapacity` + unique identity):
  `409 { "error": "full" }` when the class is full, `409 { "error": "already_enrolled" }`
  when the user already has an enrollment. (Map the Ash error: unique-constraint →
  `already_enrolled`; capacity add_error → `full`.)

### DELETE `/api/classes/:id/enroll`
Removes `current_user`'s enrollment for the class.
- `200 { "data": { "ok": true } }` on success.
- `404 { "error": "not_enrolled" }` when no enrollment exists.

### GET `/api/me/enrollments`
```json
{ "data": [
  { "id": "…", "status": "active", "enrolled_at": "…",
    "class": { "id": "…", "title": "…", "schedule": [ … ],
               "course": { "id": "…", "title": "…" } } }
] }
```

---

## 3. `seats_left/1` (domain helper, no migration)

`JosjobLrn.Learning.seats_left(class_or_id)`:
- `nil` when `capacity` is `nil` (unlimited).
- else `max(0, capacity - count(active enrollments for the class))`.

---

## 4. Files (indicative)

- Create: `apps/josjob_web/lib/josjob_web/controllers/api/catalog_controller.ex`
- Create: `apps/josjob_web/lib/josjob_web/controllers/api/enrollment_controller.ex`
- Modify: `apps/josjob_web/lib/josjob_web/router.ex` (routes under `:api_auth`)
- Modify: `apps/josjob_lrn/lib/josjob_lrn/learning.ex` (add `seats_left/1`)

Routes (inside the existing `scope "/api", JosjobWeb.Api`):
```elixir
scope "/catalog" do
  pipe_through :api_auth
  get "/courses", CatalogController, :index
  get "/courses/:id", CatalogController, :show
end

scope "/" do
  pipe_through :api_auth
  post "/classes/:id/enroll", EnrollmentController, :create
  delete "/classes/:id/enroll", EnrollmentController, :delete
  get "/me/enrollments", EnrollmentController, :index
end
```

---

## 5. Verification
- `mix compile --warnings-as-errors` and `mix format --check-formatted` clean.
- **Temporary request-tests** on the TEST DB via `JosjobWeb.ConnCase`, minting a Bearer
  access token with `AshAuthentication.Jwt.token_for_user/1` (or the `:sign_in`/token flow)
  and setting the `authorization` header; removed after they pass. Cover:
  - catalog scoping: a user sees only active courses linked to their org; a course in
    another org returns `404` on detail;
  - enroll success (`201`); capacity full → `409 "full"`; duplicate → `409 "already_enrolled"`;
    class in a non-member org → `404`;
  - unenroll success + `404 "not_enrolled"` when not enrolled;
  - `/api/me/enrollments` returns the user's enrollments.
- Manual smoke by the user (optional): hit endpoints with a real token (e.g. via
  `POST /api/auth/google` in dev or an existing token).
- **No migrations** (no schema changes). **No git** — the user commits.
