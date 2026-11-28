# Course Ecosystem — Domain Design (backend)

**Status:** approved design, ready for implementation plan
**Scope of this spec:** the backend domain layer only (new `josjob_lrn` app, Ash
resources, migrations, domain functions) **plus removing the old VOD course code/tables**.
Web UI, RBAC surfaces, and REST/Flutter are explicitly **out of scope** and become their
own later specs.

---

## 1. Purpose

Model the course "ecosystem" the way it was described in brainstorming:

```
Section/Jurusan  ("Technology Information")
  └─ Course       ("Go Programming")  — multi-tenant, categorised by section + industries
       ├─ Material  (= a document in josjob_doc, linked by course_id)
       └─ Class     (one instructor + schedule + slot capacity)
            └─ Enrollment (student registers into a CLASS, not the Course)
```

Concrete example that this design must support:

> Tenant A has course "Go Programming". Within it Tenant A has 2 instructors:
> - Instructor 1 — every Saturday 09:00–10:00, max 10 students, has own extra material.
> - Instructor 2 — every Monday & Thursday 19:00–20:00, unlimited slots, uses course
>   material only.

The old VOD `Josjob.Courses` concept (Course + Lecture + Cloudflare Stream) is **removed
entirely** (see §2.2) — this new model is the only course concept going forward.

---

## 2. Placement, wiring & cleanup

### 2.1 New home
- **`apps/josjob_lrn`** (the existing empty "learning context" stub), OTP app
  `:josjob_lrn`, single Ash domain **`JosjobLrn.Learning`**.
- Data layer: `AshPostgres.DataLayer` with **`repo: Josjob.Repo`** — the shared umbrella
  repo. Generated migrations therefore live in `apps/josjob/priv/repo/migrations`
  (same pattern already used by `josjob_doc` / `JosjobDoc.Documents`).
- Umbrella dependency direction: **`josjob_lrn → josjob`**. `josjob_lrn` depends on
  `{:josjob, in_umbrella: true}` (for `Josjob.Repo`, `Josjob.Accounts.User`,
  `Josjob.Orgs.Organization`, `Josjob.Orgs.Industry`) plus `ash`/`ash_postgres`.
  `josjob_lrn` must **not** be depended on by `josjob` (would form a cycle).
- Wiring checklist:
  - `apps/josjob_lrn/mix.exs`: add `ash`, `ash_postgres`, `{:josjob, in_umbrella: true}`.
  - `config/config.exs`: `config :josjob_lrn, ash_domains: [JosjobLrn.Learning]`, and add
    `JosjobLrn.Learning` to the `:josjob_web` `ash_domains` list (so AshAdmin sees it).
  - root `mix.exs`: add `josjob_lrn: :permanent` to the release `applications`.
  - `apps/josjob_web/mix.exs`: add `{:josjob_lrn, in_umbrella: true}`.

### 2.2 Remove the old VOD course feature (decided: "buang VOD sepenuhnya")
- Delete domain `Josjob.Courses` and its resources:
  `course.ex`, `lecture.ex`, `video_checkpoint.ex`, `transcript.ex`,
  `changes/sync_from_cloudflare.ex`.
- Remove `Josjob.Courses` from `ash_domains` in `config/config.exs` (both the `:josjob`
  and `:josjob_web` lists).
- Remove VOD web surface in `josjob_web`: routes `GET /api/courses`, `GET /api/courses/:id`,
  `GET /api/lectures/:id`, the `/vod/*` scope, the `cloudflare-stream` webhook route, and
  controllers `CourseController`, `LectureController`, `CloudflareStreamWebhookController`.
- **Knock-on:** `apps/josjob_ms` (Cloudflare Stream facade) becomes unused once VOD is
  gone. It is a **candidate for removal in a separate cleanup** — noted, not done here.

### 2.3 Database cleanup / drift (informational — user runs all DB commands)
The dev DB has **drifted** from the repo: it carries 4 applied migrations whose files were
discarded (`20260720090007`, `20260720093000`, `20260720100037`, `20260720133045`) and is
**missing** the VOD tables the committed code expects. As a result the dev DB currently
contains orphan tables **`courses`, `classes`, `materials`, `course_industries`** (leftovers
of the discarded brainstorming; no committed code maps to them) and lacks
`lectures`/`video_checkpoints`/`transcripts`.

Since VOD is being removed, all four orphan tables are dropped. Cleanest path for this
UI-only / pre-production stage: **reset the dev DB and migrate from scratch** on top of the
cleaned-up migration history. The user decides and executes this (reset + `mix ecto.migrate`
+ seed); Claude does not run migrations, seeds, or git.

---

## 3. Resources & tables

Clean table names (no prefix — the namespace is free after VOD removal). Elixir modules
live under `JosjobLrn.Learning.*`. All tables use `uuid_primary_key(:id)` and
`create_timestamp`/`update_timestamp` unless noted. All FKs are UUID.

### 3.1 `Section` — table `sections`
| field | type | notes |
|---|---|---|
| name | string | required, e.g. "Technology Information" |
| description | string | optional |
| is_active | boolean | default `true` |
| created_at / updated_at | utc_datetime_usec | `create_timestamp` / `update_timestamp` |
| created_by / updated_by | uuid (nullable) | audit trail, stamped from actor via `Josjob.Changes.StampActor` |

Relationships: `many_to_many :organizations` through `SectionOrganization`;
`has_many :courses`.

### 3.2 `SectionOrganization` — join `section_organizations`
`belongs_to :section` (`allow_nil?: false`), `organization_id :uuid` (`allow_nil?: false`,
references `organizations` in `josjob`, `on_delete: :delete`).
Identity: unique `(section_id, organization_id)`.

### 3.3 `Course` — table `courses`
| field | type | notes |
|---|---|---|
| section_id | uuid FK → `sections` | required |
| title | string | required, e.g. "Go Programming" |
| description | string | optional |
| is_active | boolean | default `true` |
| created_at / updated_at | utc_datetime_usec | `create_timestamp` / `update_timestamp` |
| created_by / updated_by | uuid (nullable) | audit trail, stamped from actor via `Josjob.Changes.StampActor` |

Relationships: `belongs_to :section` (`allow_nil?: false`);
`many_to_many :organizations` through `CourseOrganization`;
`many_to_many :industries` through `CourseIndustry`; `has_many :classes`.
No `instructor_id` (instructors live on classes). No single `industry_id`.

### 3.4 `CourseOrganization` — join `course_organizations`
`belongs_to :course` (`allow_nil?: false`), `organization_id :uuid` (`allow_nil?: false`,
references `organizations`, `on_delete: :delete`).
Identity: unique `(course_id, organization_id)`.

### 3.5 `CourseIndustry` — join `course_industries`
`belongs_to :course` (`allow_nil?: false`), `industry_id :uuid` (`allow_nil?: false`,
references `industries` in `josjob`, `on_delete: :delete`).
Identity: unique `(course_id, industry_id)`.

### 3.6 `Class` — table `classes`
| field | type | notes |
|---|---|---|
| course_id | uuid FK → `courses` | required, `on_delete: :delete` |
| organization_id | uuid → `organizations` | required — the tenant offering this class |
| instructor_id | uuid → `users` | required — the teaching user |
| title | string | optional label (e.g. "Batch Sabtu Pagi") |
| schedule | `{:array, :map}` (jsonb) | list of explicit sessions, see below |
| capacity | integer | nullable; `nil` = unlimited |

`schedule` shape — a list of explicit sessions (no recurring-rule engine):
```json
[
  {"date": "2026-08-01", "start": "09:00", "end": "10:00"},
  {"date": "2026-08-08", "start": "09:00", "end": "10:00"}
]
```
The domain does not interpret `schedule` beyond validating it is a list of maps; timezone is
assumed org-local and stored as given (no conversion in this slice).

Relationships: `belongs_to :course` (`allow_nil?: false`);
`instructor_id`/`organization_id` as UUID attributes with postgres references;
`has_many :enrollments`.

### 3.7 `Enrollment` — table `enrollments`
| field | type | notes |
|---|---|---|
| class_id | uuid FK → `classes` | required, `on_delete: :delete` |
| student_id | uuid → `users` | required |
| status | atom | one_of `[:active, :completed]`, default `:active` |
| enrolled_at | utc_datetime_usec | default now |

Identity: unique `(class_id, student_id)` — a student cannot enroll twice in the same class.

### 3.8 `documents` (existing `josjob_doc`) — reused as **Material**
No schema change. Columns already present: `title`, `url`, `mime_type`, `description`,
`course_id` (uuid, nullable, currently unused — all rows null), `user_id`, `organization_id`.
`mime_type` carries the "type" (pdf / video / …). `course_id` now points at `courses.id`
**as a plain UUID** (no cross-app DB FK — avoids coupling `josjob_doc → josjob_lrn`).

---

## 4. Key domain behavior

### 4.1 Material resolution for a class
Given a class with `course_id = C` and `instructor_id = U`, its materials are the union of:
- **Course materials:** `documents` where `course_id == C` (shared to every tenant that
  offers course C).
- **Instructor materials:** `documents` where `user_id == U` **and** `course_id` is `NULL`.

⚠️ **Accepted limitation (per the "combination of columns" decision):** because there is no
`kind` discriminator, *every* `course_id`-null document owned by an instructor surfaces as
instructor material in the classes they teach — i.e. an instructor's personal bank documents
are treated as teaching supplements. This trade-off was explicitly accepted; it can be
tightened later by adding a `kind` enum (`course | instructor | personal`) to `documents`
without changing this resolution's shape.

Expose as `JosjobLrn.Learning.materials_for_class/1` (accepts a class or class_id),
returning the combined document list. Reading `documents` from `josjob_lrn` goes through
`JosjobDoc.Documents` (add `:josjob_doc` as a dependency of `:josjob_lrn`, or via a small
facade) — the exact seam is an implementation detail for the plan.

### 4.2 Enrollment with capacity
`Enrollment` create action:
- If the class `capacity` is `nil` → always allowed.
- Else count existing `:active` enrollments for the class; reject when `count >= capacity`
  (validation error, not a crash).
- Unique `(class_id, student_id)` prevents double enrollment.

Capacity counting runs inside the create action; a race that overshoots capacity under heavy
concurrency is acceptable for this slice (no row-locking yet) — note it as a known follow-up,
do not build a locking mechanism now.

### 4.3 Multi-tenant visibility
- A tenant "has" a section/course when a `SectionOrganization`/`CourseOrganization` row links
  them. Helper reads: `sections_for_org/1`, `courses_for_org/1`.
- Course materials (documents with `course_id`) are shared across all tenants offering the
  course. Instructor materials follow the instructor into their classes only.

---

## 5. Out of scope (future specs)
- Admin web UI: CRUD for sections/courses/classes, attach-material flow, enrollment mgmt.
- RBAC: new permission keys + menu/route/action gating + per-org data scoping for the
  surfaces above. (Note: `courses:read` / `courses:manage` permission rows already exist in
  the DB and can be reused.)
- REST API / Flutter student-facing flows (catalog, class browse, enroll).
- Removal of the now-unused `apps/josjob_ms` app.
- A `kind` discriminator on `documents` (only if the §4.1 limitation becomes a problem).

---

## 6. Verification
- `mix compile --warnings-as-errors` and `mix format --check-formatted` clean (CI
  `precommit` runs both). After VOD removal there must be **no dangling references** to
  `Josjob.Courses`, the VOD controllers, or their routes.
- Resources + migrations generated via `mix ash.codegen <name>`; the drop of the old
  `courses`/`classes`/`materials`/`course_industries` tables and creation of the new model is
  reflected in migrations.
- Correctness verified with **temporary ExUnit tests on the TEST database only** (material
  resolution for a class incl. course+instructor union; enrollment capacity limit + unlimited;
  double-enroll rejected; multi-tenant course sharing). Temp tests are removed after they pass.
- **Do not** run `mix ecto.migrate` / seed / DB reset against the dev DB — the user runs those.
  Deploy runs `bin/migrate` + `bin/seed` automatically.
- **Do not** run any git command — the user handles all commits.
