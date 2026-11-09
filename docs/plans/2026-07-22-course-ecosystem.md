# Course Ecosystem (backend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the course-ecosystem domain (Section → Course → Class → Enrollment, with materials = documents) in a new `stellar_lrn` app, and remove the old VOD course feature.

**Architecture:** New Ash domain `StellarLrn.Learning` in `apps/stellar_lrn`, using the shared `Stellar.Repo`. Old `Stellar.Courses` (VOD) is deleted; a drop-migration removes its tables. New tables are created fresh. `documents` (in `stellar_doc`) is reused unchanged as "Material", linked by a plain `course_id` uuid.

**Tech Stack:** Elixir umbrella, Ash 3.x + AshPostgres 2.x, PostgreSQL (dev on port 5438), ExUnit.

## Global Constraints

- **NEVER run any git command.** The user handles all commits. Commit steps below are FYI checkpoints for the user; do not execute them.
- **NEVER run migrations/seed/DB-reset against the dev DB.** Only the **TEST** database may be migrated for verification (`MIX_ENV=test`). Deploy runs `bin/migrate`+`bin/seed` automatically; the user resets the dev DB.
- New backend code goes in the app that owns the concern: course ecosystem → `apps/stellar_lrn`. Migrations + snapshots for `Stellar.Repo` live under `apps/stellar/priv/`.
- Dependency direction: `stellar_lrn → stellar` and `stellar_lrn → stellar_doc`. `stellar_lrn` must NOT be a dependency of `stellar`/`stellar_doc` (cycle).
- Table names are clean (no prefix): `sections`, `courses`, `classes`, `enrollments`, `section_organizations`, `course_organizations`, `course_industries`.
- Verify with: `mix compile --warnings-as-errors` and `mix format --check-formatted` clean (from repo root). Behavior tests run on the TEST DB and are **removed after they pass** (project norm).
- Resources use `otp_app: :stellar_lrn`, `data_layer: AshPostgres.DataLayer`, `domain: StellarLrn.Learning`, `repo(Stellar.Repo)`.

---

### Task 1: Scaffold `stellar_lrn` app + empty domain + wiring

**Files:**
- Modify: `apps/stellar_lrn/mix.exs`
- Create: `apps/stellar_lrn/.formatter.exs`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning.ex`
- Modify: `config/config.exs`
- Modify: `apps/stellar_web/mix.exs:60-66` (deps list)
- Modify: `apps/stellar_lrn/test/test_helper.exs`
- Create: `apps/stellar_lrn/test/support/data_case.ex`

**Interfaces:**
- Produces: Ash domain `StellarLrn.Learning` (empty `resources do end` for now); OTP app `:stellar_lrn` depending on `:stellar` + `:stellar_doc` + `ash` + `ash_postgres`.

- [ ] **Step 1: Set `stellar_lrn` deps**

Replace the `deps/0` in `apps/stellar_lrn/mix.exs` with:

```elixir
  defp deps do
    [
      # User/Org/Industry/Repo live in :stellar; documents (Material) in :stellar_doc.
      {:stellar, in_umbrella: true},
      {:stellar_doc, in_umbrella: true},
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"}
    ]
  end
```

Also add `elixirc_paths` so the test-support dir compiles only in test. Change `project/0` to include:

```elixir
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
```

and add these private functions after `project/0`:

```elixir
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
```

- [ ] **Step 2: Add formatter**

Create `apps/stellar_lrn/.formatter.exs`:

```elixir
[
  import_deps: [:ash, :ash_postgres],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

- [ ] **Step 3: Create the empty domain**

Create `apps/stellar_lrn/lib/stellar_lrn/learning.ex`:

```elixir
defmodule StellarLrn.Learning do
  @moduledoc """
  Domain ekosistem course: Section → Course → Class → Enrollment.
  Material = dokumen di `StellarDoc.Documents` (dihubungkan lewat `course_id`).
  Pakai `Stellar.Repo`; enforcement lewat query-scope (bukan Ash policy global).
  """
  use Ash.Domain

  resources do
  end
end
```

- [ ] **Step 4: Wire config**

In `config/config.exs`, register the new domain. After the `config :stellar_doc, ash_domains: ...` line add:

```elixir
config :stellar_lrn, ash_domains: [StellarLrn.Learning]
```

- [ ] **Step 5: Register domain with AshAdmin (stellar_web)**

In `config/config.exs`, in the `config :stellar_web, ... ash_domains: [...]` list, add `StellarLrn.Learning` (keep the others; `Stellar.Courses` is removed in Task 2).

- [ ] **Step 6: Add stellar_lrn to stellar_web deps**

In `apps/stellar_web/mix.exs` deps, after `{:stellar_doc, in_umbrella: true},` add:

```elixir
      {:stellar_lrn, in_umbrella: true},
```

- [ ] **Step 7: Add a DataCase for TEST-DB tests**

Create `apps/stellar_lrn/test/support/data_case.ex`:

```elixir
defmodule StellarLrn.DataCase do
  @moduledoc "Test case that checks out an Ecto sandbox connection on Stellar.Repo."
  use ExUnit.CaseTemplate

  using do
    quote do
      require Ash.Query
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Stellar.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

Replace `apps/stellar_lrn/test/test_helper.exs` with:

```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Stellar.Repo, :manual)
```

- [ ] **Step 8: Verify compile**

Run: `mix compile`
Expected: compiles (the empty domain triggers no Ash "empty domain" error; if it warns, that's acceptable at this stage). No errors.

- [ ] **Step 9: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn config/config.exs apps/stellar_web/mix.exs
git commit -m "feat(lrn): scaffold stellar_lrn app + empty Learning domain"
```

---

### Task 2: Remove the VOD course feature + drop its tables

**Files:**
- Delete: `apps/stellar/lib/stellar/courses/` (whole dir: `course.ex`, `lecture.ex`, `video_checkpoint.ex`, `transcript.ex`, `changes/sync_from_cloudflare.ex`)
- Delete: `apps/stellar/lib/stellar/courses.ex` (the `Stellar.Courses` domain module)
- Delete orphan snapshots: `apps/stellar/priv/resource_snapshots/repo/{classes,materials,course_industries}/`
- Modify: `config/config.exs` (remove `Stellar.Courses` from both `ash_domains` lists)
- Modify: `apps/stellar_web/lib/stellar_web/router.ex` (remove VOD routes)
- Delete: `apps/stellar_web/lib/stellar_web/controllers/api/course_controller.ex`, `.../lecture_controller.ex`, `.../cloudflare_stream_webhook_controller.ex` (and their JSON views if any: `.../api/course_json.ex`, `.../api/lecture_json.ex` — delete only if present)
- Generated: a new drop migration under `apps/stellar/priv/repo/migrations/`

**Interfaces:**
- Produces: a repo with no `Stellar.Courses` domain, no VOD routes, and a migration dropping `courses`, `lectures`, `video_checkpoints`, `transcripts`.

- [ ] **Step 1: Confirm the VOD domain module path**

Run: `ls apps/stellar/lib/stellar/courses.ex apps/stellar/lib/stellar/courses/`
Expected: lists `courses.ex` and the resource files. (If `courses.ex` is named differently, note the actual `Stellar.Courses` domain file before deleting.)

- [ ] **Step 2: Delete VOD code**

Run:
```bash
rm -rf apps/stellar/lib/stellar/courses apps/stellar/lib/stellar/courses.ex
```

- [ ] **Step 3: Delete orphan snapshots (no resource, no committed migration)**

Run:
```bash
rm -rf apps/stellar/priv/resource_snapshots/repo/classes \
       apps/stellar/priv/resource_snapshots/repo/materials \
       apps/stellar/priv/resource_snapshots/repo/course_industries
```

- [ ] **Step 4: Remove `Stellar.Courses` from config**

In `config/config.exs`, edit the `:stellar` `ash_domains` (remove `, Stellar.Courses`) and the `:stellar_web` `ash_domains` list (remove the `Stellar.Courses,` line). Leave `StellarDoc.Documents` and the new `StellarLrn.Learning` in place.

- [ ] **Step 5: Remove VOD routes**

In `apps/stellar_web/lib/stellar_web/router.ex`, delete these lines from the `/api` scope:

```elixir
    get "/courses", CourseController, :index
    get "/courses/:id", CourseController, :show
    get "/lectures/:id", LectureController, :show
```

the entire `cloudflare-stream` webhook route:

```elixir
    post "/webhooks/cloudflare-stream", CloudflareStreamWebhookController, :handle
```

and the entire `/vod` scope block:

```elixir
    scope "/vod" do
      pipe_through :api_auth

      post "/courses", CourseController, :create
      post "/courses/:course_id/lectures", LectureController, :request_upload
      post "/lectures/:id/refresh", LectureController, :refresh
    end
```

- [ ] **Step 6: Delete the VOD controllers**

Run (delete only files that exist):
```bash
rm -f apps/stellar_web/lib/stellar_web/controllers/api/course_controller.ex \
      apps/stellar_web/lib/stellar_web/controllers/api/lecture_controller.ex \
      apps/stellar_web/lib/stellar_web/controllers/api/cloudflare_stream_webhook_controller.ex \
      apps/stellar_web/lib/stellar_web/controllers/api/course_json.ex \
      apps/stellar_web/lib/stellar_web/controllers/api/lecture_json.ex
```

- [ ] **Step 7: Verify no dangling references**

Run: `grep -rn "Stellar.Courses\|CloudflareStreamWebhookController\|CourseController\|LectureController" apps/*/lib config`
Expected: no matches. If any remain (e.g. an alias, `StellarMs` call, or seed reference), remove them. Then:

Run: `mix compile --warnings-as-errors`
Expected: compiles with no warnings/errors.

- [ ] **Step 8: Generate the drop migration**

Run: `mix ash.codegen drop_vod_courses`
Expected: creates a migration in `apps/stellar/priv/repo/migrations/` that drops `transcripts`, `video_checkpoints`, `lectures`, `courses` (dependents first). Open the file and confirm it only drops those four tables (no unexpected `create`/`alter`). If it also references `classes`/`materials`/`course_industries`, the orphan snapshots were not fully removed — redo Step 3 and regenerate.

- [ ] **Step 9: Verify the migration applies on the TEST DB**

Run:
```bash
cd apps/stellar && MIX_ENV=test mix ecto.drop && MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate && cd ../..
```
Expected: all migrations run cleanly; the four VOD tables get created by the old migrations then dropped by the new one. No errors.

- [ ] **Step 10: Format**

Run: `mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 11: Commit (USER runs git — do not execute)**

```bash
git add -A
git commit -m "refactor: remove VOD course feature + drop its tables"
```

---

### Task 3: Taxonomy resources — Section, Course + join tables

**Files:**
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/section.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/section_organization.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/course.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/course_organization.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/course_industry.ex`
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning.ex` (register resources)
- Test (temp): `apps/stellar_lrn/test/learning/taxonomy_test.exs`
- Generated: migration under `apps/stellar/priv/repo/migrations/`

**Interfaces:**
- Produces:
  - `StellarLrn.Learning.Section` (table `sections`): `name:string!`, `description:string`, `is_active:boolean=true`; `many_to_many :organizations`; `has_many :courses`.
  - `StellarLrn.Learning.SectionOrganization` (table `section_organizations`): `belongs_to :section`, `belongs_to :organization`; identity `(section_id, organization_id)`.
  - `StellarLrn.Learning.Course` (table `courses`): `belongs_to :section!`, `title:string!`, `description:string`, `is_active:boolean=true`; `many_to_many :organizations`, `many_to_many :industries`; `has_many :classes`.
  - `StellarLrn.Learning.CourseOrganization` (table `course_organizations`): `belongs_to :course`, `belongs_to :organization`; identity `(course_id, organization_id)`.
  - `StellarLrn.Learning.CourseIndustry` (table `course_industries`): `belongs_to :course`, `belongs_to :industry`; identity `(course_id, industry_id)`.

- [ ] **Step 1: Create `SectionOrganization`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/section_organization.ex`:

```elixir
defmodule StellarLrn.Learning.SectionOrganization do
  @moduledoc "Join section ↔ organization (tenant yang punya section)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("section_organizations")
    repo(Stellar.Repo)

    references do
      reference(:section, on_delete: :delete)
      reference(:organization, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :section, StellarLrn.Learning.Section do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_section_organization, [:section_id, :organization_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:section_id, :organization_id])
  end
end
```

- [ ] **Step 2: Create `Section`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/section.ex`:

```elixir
defmodule StellarLrn.Learning.Section do
  @moduledoc "Section / jurusan (mis. \"Technology Information\"). Multi-tenant (M:N org)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("sections")
    repo(Stellar.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:is_active, :boolean, allow_nil?: false, default: true, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :courses, StellarLrn.Learning.Course do
      public?(true)
    end

    many_to_many :organizations, Stellar.Orgs.Organization do
      through(StellarLrn.Learning.SectionOrganization)
      source_attribute_on_join_resource(:section_id)
      destination_attribute_on_join_resource(:organization_id)
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:name, :description, :is_active])
  end
end
```

- [ ] **Step 3: Create `CourseOrganization`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/course_organization.ex`:

```elixir
defmodule StellarLrn.Learning.CourseOrganization do
  @moduledoc "Join course ↔ organization (tenant yang memakai course)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("course_organizations")
    repo(Stellar.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:organization, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :course, StellarLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_course_organization, [:course_id, :organization_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:course_id, :organization_id])
  end
end
```

- [ ] **Step 4: Create `CourseIndustry`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/course_industry.ex`:

```elixir
defmodule StellarLrn.Learning.CourseIndustry do
  @moduledoc "Join course ↔ industry (satu course bisa banyak industri)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("course_industries")
    repo(Stellar.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:industry, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to :course, StellarLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :industry, Stellar.Orgs.Industry do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_course_industry, [:course_id, :industry_id])
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:course_id, :industry_id])
  end
end
```

- [ ] **Step 5: Create `Course`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/course.ex`:

```elixir
defmodule StellarLrn.Learning.Course do
  @moduledoc """
  Course (mis. \"Go Programming\"). Multi-tenant (M:N org), berkategori section +
  banyak industry. Pengajar TIDAK di sini — ada di Class. Material = dokumen
  (StellarDoc) dengan `course_id` == id course ini.
  """
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("courses")
    repo(Stellar.Repo)

    references do
      reference(:section, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:is_active, :boolean, allow_nil?: false, default: true, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :section, StellarLrn.Learning.Section do
      allow_nil?(false)
      public?(true)
    end

    has_many :classes, StellarLrn.Learning.Class do
      public?(true)
    end

    many_to_many :organizations, Stellar.Orgs.Organization do
      through(StellarLrn.Learning.CourseOrganization)
      source_attribute_on_join_resource(:course_id)
      destination_attribute_on_join_resource(:organization_id)
      public?(true)
    end

    many_to_many :industries, Stellar.Orgs.Industry do
      through(StellarLrn.Learning.CourseIndustry)
      source_attribute_on_join_resource(:course_id)
      destination_attribute_on_join_resource(:industry_id)
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:title, :description, :is_active, :section_id])
  end
end
```

Note: `Course` references `StellarLrn.Learning.Class` (created in Task 4). Until then compilation of the `has_many :classes` will fail — so create the `Class` resource (Task 4 Step 1) before compiling, OR temporarily comment the `has_many :classes` line and restore it in Task 4. Recommended: do Task 4 Step 1 now, then continue. (This note exists because tasks may be read out of order.)

- [ ] **Step 6: Register taxonomy resources in the domain**

Edit `apps/stellar_lrn/lib/stellar_lrn/learning.ex` `resources do` block to:

```elixir
  resources do
    resource(StellarLrn.Learning.Section)
    resource(StellarLrn.Learning.SectionOrganization)
    resource(StellarLrn.Learning.Course)
    resource(StellarLrn.Learning.CourseOrganization)
    resource(StellarLrn.Learning.CourseIndustry)
  end
```

(Class and Enrollment are added to this block in Task 4.)

- [ ] **Step 7: Generate the migration**

Run: `mix ash.codegen add_learning_taxonomy`
Expected: a migration that CREATEs `sections`, `section_organizations`, `courses`, `course_organizations`, `course_industries` with the FKs and unique indexes. Open it and confirm: no `alter`/`drop` of unrelated tables, unique indexes on each join `(x_id, y_id)`.

- [ ] **Step 8: Migrate the TEST DB**

Run: `cd apps/stellar && MIX_ENV=test mix ecto.migrate && cd ../..`
Expected: applies cleanly.

- [ ] **Step 9: Write a temp test proving the schema + relationships work**

Create `apps/stellar_lrn/test/learning/taxonomy_test.exs`:

```elixir
defmodule StellarLrn.Learning.TaxonomyTest do
  use StellarLrn.DataCase, async: false

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Section, Course, CourseOrganization}

  defp org! do
    # An organization requires a user (owner). Create both directly via Ash.
    {:ok, user} =
      Stellar.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "t#{System.unique_integer([:positive])}@ex.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Ash.create(authorize?: false)

    {:ok, org} =
      Stellar.Orgs.Organization
      |> Ash.Changeset.for_create(:create, %{name: "Org #{System.unique_integer([:positive])}", user_id: user.id})
      |> Ash.create(authorize?: false)

    org
  end

  test "section → course, and course is shared to a tenant via join" do
    {:ok, section} =
      Section |> Ash.Changeset.for_create(:create, %{name: "Technology Information"}) |> Ash.create(authorize?: false)

    {:ok, course} =
      Course
      |> Ash.Changeset.for_create(:create, %{title: "Go Programming", section_id: section.id})
      |> Ash.create(authorize?: false)

    org = org!()

    {:ok, _} =
      CourseOrganization
      |> Ash.Changeset.for_create(:create, %{course_id: course.id, organization_id: org.id})
      |> Ash.create(authorize?: false)

    loaded = Ash.load!(course, [:organizations, :section], authorize?: false)
    assert loaded.section.name == "Technology Information"
    assert Enum.map(loaded.organizations, & &1.id) == [org.id]
  end
end
```

Note: if `Stellar.Accounts.User`'s registration action name/args differ, adjust `org!/0` to however users are created elsewhere in tests (check `apps/stellar_web/test/support` or existing factories). The point of the helper is a valid `organization`.

- [ ] **Step 10: Run the test**

Run: `cd apps/stellar_lrn && MIX_ENV=test mix test test/learning/taxonomy_test.exs && cd ../..`
Expected: PASS.

- [ ] **Step 11: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn apps/stellar/priv
git commit -m "feat(lrn): add Section/Course + join tables"
```

---

### Task 4: Delivery resources — Class + Enrollment (with capacity)

**Files:**
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/class.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/enrollment.ex`
- Create: `apps/stellar_lrn/lib/stellar_lrn/learning/changes/check_capacity.ex`
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning.ex` (register Class + Enrollment)
- Test (temp): `apps/stellar_lrn/test/learning/enrollment_test.exs`
- Generated: migration under `apps/stellar/priv/repo/migrations/`

**Interfaces:**
- Consumes: `StellarLrn.Learning.Course` (Task 3), `Stellar.Accounts.User`, `Stellar.Orgs.Organization`.
- Produces:
  - `StellarLrn.Learning.Class` (table `classes`): `belongs_to :course!`, `organization_id`+`instructor_id` (belongs_to), `title:string`, `schedule:{:array,:map}=[]`, `capacity:integer` (nil=unlimited); `has_many :enrollments`.
  - `StellarLrn.Learning.Enrollment` (table `enrollments`): `belongs_to :class!`, `belongs_to :student` (User), `status:atom in [:active,:completed]=:active`, `enrolled_at:utc_datetime_usec`; identity `(class_id, student_id)`; `:create` runs `CheckCapacity`.

- [ ] **Step 1: Create `Class`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/class.ex`:

```elixir
defmodule StellarLrn.Learning.Class do
  @moduledoc """
  Kelas: satu penyelenggaraan course oleh SATU pengajar (instructor), dengan
  jadwal (daftar sesi) + kapasitas slot (nil = tak terbatas). Milik satu tenant.
  """
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("classes")
    repo(Stellar.Repo)

    references do
      reference(:course, on_delete: :delete)
      reference(:organization, on_delete: :delete)
      reference(:instructor, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
    # Daftar sesi eksplisit: [%{"date" => "2026-08-01", "start" => "09:00", "end" => "10:00"}].
    attribute(:schedule, {:array, :map}, allow_nil?: false, default: [], public?: true)
    # null = slot tak terbatas.
    attribute(:capacity, :integer, public?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :course, StellarLrn.Learning.Course do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organization, Stellar.Orgs.Organization do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :instructor, Stellar.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    has_many :enrollments, StellarLrn.Learning.Enrollment do
      public?(true)
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
    default_accept([:title, :schedule, :capacity, :course_id, :organization_id, :instructor_id])
  end
end
```

- [ ] **Step 2: Create the capacity change**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/changes/check_capacity.ex`:

```elixir
defmodule StellarLrn.Learning.Changes.CheckCapacity do
  @moduledoc """
  Tolak enrollment bila kelas penuh. `capacity` nil = tak terbatas. Hitung
  enrollment berstatus :active di kelas tsb; error bila count >= capacity.
  (Belum ada row-lock; race saat konkuren tinggi diterima untuk slice ini.)
  """
  use Ash.Resource.Change
  require Ash.Query

  alias StellarLrn.Learning.{Class, Enrollment}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      class_id = Ash.Changeset.get_attribute(cs, :class_id)

      with false <- is_nil(class_id),
           {:ok, %Class{capacity: capacity}} when not is_nil(capacity) <-
             Ash.get(Class, class_id, authorize?: false) do
        active =
          Enrollment
          |> Ash.Query.filter(class_id == ^class_id and status == :active)
          |> Ash.count!(authorize?: false)

        if active >= capacity do
          Ash.Changeset.add_error(cs, field: :class_id, message: "class is full")
        else
          cs
        end
      else
        _ -> cs
      end
    end)
  end
end
```

- [ ] **Step 3: Create `Enrollment`**

Create `apps/stellar_lrn/lib/stellar_lrn/learning/enrollment.ex`:

```elixir
defmodule StellarLrn.Learning.Enrollment do
  @moduledoc "Pendaftaran siswa ke sebuah Class. Unik per (class, student)."
  use Ash.Resource,
    otp_app: :stellar_lrn,
    data_layer: AshPostgres.DataLayer,
    domain: StellarLrn.Learning

  postgres do
    table("enrollments")
    repo(Stellar.Repo)

    references do
      reference(:class, on_delete: :delete)
      reference(:student, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :active,
      constraints: [one_of: [:active, :completed]],
      public?: true
    )

    attribute(:enrolled_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true
    )

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :class, StellarLrn.Learning.Class do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :student, Stellar.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_class_student, [:class_id, :student_id])
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      accept([:class_id, :student_id, :status])
      change(StellarLrn.Learning.Changes.CheckCapacity)
    end
  end
end
```

- [ ] **Step 4: Register Class + Enrollment**

Edit `apps/stellar_lrn/lib/stellar_lrn/learning.ex` `resources do` block, adding:

```elixir
    resource(StellarLrn.Learning.Class)
    resource(StellarLrn.Learning.Enrollment)
```

- [ ] **Step 5: Compile**

Run: `mix compile --warnings-as-errors`
Expected: clean (this also resolves the `has_many :classes` reference in `Course`).

- [ ] **Step 6: Generate the migration**

Run: `mix ash.codegen add_learning_delivery`
Expected: a migration creating `classes` and `enrollments` with FKs, the `(class_id, student_id)` unique index, and the `status`/`capacity`/`schedule` columns. Confirm no unrelated alters/drops.

- [ ] **Step 7: Migrate the TEST DB**

Run: `cd apps/stellar && MIX_ENV=test mix ecto.migrate && cd ../..`
Expected: applies cleanly.

- [ ] **Step 8: Write temp tests for capacity + double-enroll**

Create `apps/stellar_lrn/test/learning/enrollment_test.exs`:

```elixir
defmodule StellarLrn.Learning.EnrollmentTest do
  use StellarLrn.DataCase, async: false

  alias StellarLrn.Learning.{Section, Course, Class, Enrollment}

  defp user! do
    {:ok, u} =
      Stellar.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "u#{System.unique_integer([:positive])}@ex.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
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

  defp class!(capacity) do
    instructor = user!()
    org = org!(instructor)
    {:ok, section} = Section |> Ash.Changeset.for_create(:create, %{name: "Sec"}) |> Ash.create(authorize?: false)

    {:ok, course} =
      Course |> Ash.Changeset.for_create(:create, %{title: "C", section_id: section.id}) |> Ash.create(authorize?: false)

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

  defp enroll(class, student) do
    Enrollment
    |> Ash.Changeset.for_create(:create, %{class_id: class.id, student_id: student.id})
    |> Ash.create(authorize?: false)
  end

  test "unlimited capacity (nil) always allows enrollment" do
    class = class!(nil)
    assert {:ok, _} = enroll(class, user!())
    assert {:ok, _} = enroll(class, user!())
  end

  test "capacity limit rejects the over-limit enrollment" do
    class = class!(1)
    assert {:ok, _} = enroll(class, user!())
    assert {:error, _} = enroll(class, user!())
  end

  test "same student cannot enroll twice in the same class" do
    class = class!(nil)
    student = user!()
    assert {:ok, _} = enroll(class, student)
    assert {:error, _} = enroll(class, student)
  end
end
```

- [ ] **Step 9: Run the tests**

Run: `cd apps/stellar_lrn && MIX_ENV=test mix test test/learning/enrollment_test.exs && cd ../..`
Expected: 3 tests PASS.

- [ ] **Step 10: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn apps/stellar/priv
git commit -m "feat(lrn): add Class + Enrollment with capacity + unique guard"
```

---

### Task 5: Domain helpers — materials + tenant scoping

**Files:**
- Modify: `apps/stellar_lrn/lib/stellar_lrn/learning.ex` (add helper functions)
- Test (temp): `apps/stellar_lrn/test/learning/materials_test.exs`

**Interfaces:**
- Consumes: `StellarDoc.Documents.Document`, `StellarLrn.Learning.{Class,Section,Course}`.
- Produces:
  - `StellarLrn.Learning.materials_for_class(class_or_id)` → `[Document]` (course materials ∪ instructor materials).
  - `StellarLrn.Learning.sections_for_org(org_id)` → `[Section]`.
  - `StellarLrn.Learning.courses_for_org(org_id)` → `[Course]`.

- [ ] **Step 1: Add helpers to the domain**

Edit `apps/stellar_lrn/lib/stellar_lrn/learning.ex`: add `require Ash.Query` and aliases below `use Ash.Domain`, and add the functions after the `resources do ... end` block:

```elixir
  require Ash.Query
  alias StellarLrn.Learning.{Section, Course, Class}
  alias StellarDoc.Documents.Document

  @doc """
  Materi sebuah kelas = union:
    * materi kursus  → documents dengan `course_id` == course kelas ini
    * materi pengajar → documents milik instructor (`user_id`) yang `course_id` null
  """
  def materials_for_class(%Class{} = class), do: do_materials(class)

  def materials_for_class(class_id) when is_binary(class_id) do
    case Ash.get(Class, class_id, authorize?: false) do
      {:ok, class} -> do_materials(class)
      _ -> []
    end
  end

  defp do_materials(%Class{course_id: course_id, instructor_id: instructor_id}) do
    Document
    |> Ash.Query.filter(
      course_id == ^course_id or (user_id == ^instructor_id and is_nil(course_id))
    )
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  @doc "Section yang dimiliki tenant `org_id` (lewat join section_organizations)."
  def sections_for_org(org_id) when is_binary(org_id) do
    Section
    |> Ash.Query.filter(organizations.id == ^org_id)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
  end

  @doc "Course yang dipakai tenant `org_id` (lewat join course_organizations)."
  def courses_for_org(org_id) when is_binary(org_id) do
    Course
    |> Ash.Query.filter(organizations.id == ^org_id)
    |> Ash.Query.sort(title: :asc)
    |> Ash.read!(authorize?: false)
  end
```

- [ ] **Step 2: Compile**

Run: `mix compile --warnings-as-errors`
Expected: clean.

- [ ] **Step 3: Write a temp test for material resolution**

Create `apps/stellar_lrn/test/learning/materials_test.exs`:

```elixir
defmodule StellarLrn.Learning.MaterialsTest do
  use StellarLrn.DataCase, async: false

  alias StellarLrn.Learning
  alias StellarLrn.Learning.{Section, Course, Class}
  alias StellarDoc.Documents.Document

  defp user! do
    {:ok, u} =
      Stellar.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "m#{System.unique_integer([:positive])}@ex.com",
        password: "password1234",
        password_confirmation: "password1234"
      })
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

  defp doc!(attrs) do
    {:ok, d} = Document |> Ash.Changeset.for_create(:create, attrs) |> Ash.create(authorize?: false)
    d
  end

  test "materials_for_class = course materials ∪ instructor's course_id-null docs" do
    instructor = user!()
    other = user!()
    org = org!(instructor)
    {:ok, section} = Section |> Ash.Changeset.for_create(:create, %{name: "S"}) |> Ash.create(authorize?: false)
    {:ok, course} = Course |> Ash.Changeset.for_create(:create, %{title: "Go", section_id: section.id}) |> Ash.create(authorize?: false)

    {:ok, class} =
      Class
      |> Ash.Changeset.for_create(:create, %{course_id: course.id, organization_id: org.id, instructor_id: instructor.id})
      |> Ash.create(authorize?: false)

    course_mat = doc!(%{title: "Course PDF", url: "http://x/1", course_id: course.id, user_id: other.id, organization_id: org.id})
    instr_mat = doc!(%{title: "Instructor extra", url: "http://x/2", user_id: instructor.id, organization_id: org.id})
    # Noise: another instructor's personal doc, and a different course's material — must NOT appear.
    _noise1 = doc!(%{title: "Other personal", url: "http://x/3", user_id: other.id, organization_id: org.id})
    _noise2 = doc!(%{title: "Other course", url: "http://x/4", course_id: Ash.UUID.generate(), user_id: other.id, organization_id: org.id})

    ids = Learning.materials_for_class(class) |> Enum.map(& &1.id) |> MapSet.new()
    assert MapSet.equal?(ids, MapSet.new([course_mat.id, instr_mat.id]))
  end
end
```

- [ ] **Step 4: Run the test**

Run: `cd apps/stellar_lrn && MIX_ENV=test mix test test/learning/materials_test.exs && cd ../..`
Expected: PASS.

- [ ] **Step 5: Commit (USER runs git — do not execute)**

```bash
git add apps/stellar_lrn
git commit -m "feat(lrn): materials_for_class + tenant-scoped section/course helpers"
```

---

### Task 6: Final verification + remove temp tests

**Files:**
- Delete: `apps/stellar_lrn/test/learning/taxonomy_test.exs`, `.../enrollment_test.exs`, `.../materials_test.exs`

- [ ] **Step 1: Full compile (warnings as errors)**

Run: `mix compile --warnings-as-errors`
Expected: clean, no dangling VOD references.

- [ ] **Step 2: Format check**

Run: `mix format && mix format --check-formatted`
Expected: clean.

- [ ] **Step 3: Full test suite on TEST DB**

Run: `mix test`
Expected: all pass (existing suite + the 3 new temp test files). If anything referencing VOD in the existing suite fails, remove/adjust that stale test (note it in the commit).

- [ ] **Step 4: Remove the temp tests (project norm: temp tests deleted after passing)**

Run:
```bash
rm -f apps/stellar_lrn/test/learning/taxonomy_test.exs \
      apps/stellar_lrn/test/learning/enrollment_test.exs \
      apps/stellar_lrn/test/learning/materials_test.exs
```

- [ ] **Step 5: Re-verify compile + format after deletion**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: clean.

- [ ] **Step 6: Commit (USER runs git — do not execute)**

```bash
git add -A
git commit -m "chore(lrn): remove temp verification tests; course ecosystem backend complete"
```

---

## Post-plan handoff to the user (not steps)

- **Dev DB:** reset + migrate + seed is the user's job (dev DB drifted; see spec §2.3). Suggested: `cd apps/stellar && MIX_ENV=dev mix ecto.reset` (or drop/create/migrate), then re-seed. Claude will not run these.
- **Git:** all commits above are the user's.
- **Deferred (future specs):** admin UI, RBAC gating (reuse existing `courses:read`/`courses:manage` permissions), REST/Flutter, removal of the now-unused `apps/stellar_ms`.
