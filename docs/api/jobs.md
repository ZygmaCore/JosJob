# Job listings API

This implements the job-listing slice of `PRD/backdev/PRD.md` sections 3, 6
and 7, and `PRD/frontdev/PRD.md` section 4. CV analysis, ranked recommendations,
saved jobs, and applications are separate work. No match scores are fabricated.

All endpoints require a Bearer access token. Reads are scoped to active
organization memberships with `jobs:read`, `jobs:post` or `jobs:manage`.
Unprovisioned users receive an empty collection. Platform superusers bypass
the permission restriction. Inaccessible job IDs return 404.

| Method / path | Behavior |
| --- | --- |
| `GET /api/jobs` | Paginated active job listings in the caller's authorized organizations |
| `GET /api/jobs/:id` | Full listing, company name, skills, responsibilities and management capability |
| `POST /api/jobs` | Create in a specified organization with `jobs:post` |
| `PATCH /api/jobs/:id` | Update fields with `jobs:manage` in the owning organization |
| `DELETE /api/jobs/:id` | Delete with `jobs:manage`; returns 204 |

## Listing filters

`q` searches title, description and company without case sensitivity.
`employment_type` accepts `full-time`, `part-time`, `internship`, `contract`,
or `freelance`. `work_mode` accepts `remote`, `hybrid`, or `onsite`.
`location` and `industry` are case-insensitive text filters.

`salary_min` selects listings whose disclosed maximum salary reaches the
requested minimum. Amounts are whole currency units **per month**, not cents.
Select a three-letter `currency` when using salary filtering or salary sorting;
the API does not compare or convert amounts across currencies.

`sort=newest` is the default; `sort=salary` orders disclosed maximum salaries
descending, undisclosed amounts last. Both use stable tie-breakers.
`page` starts at 1 (maximum 10,000); `page_size` defaults to 12 (maximum 50).
Invalid values return 400 with `error: "invalid_params"` and `fields`.

`scope=manage` returns all statuses only in organizations where the caller can
post/manage; `status=draft|active|expired` may narrow that management view.
The ordinary browse scope always restricts results to active listings.

The response contains `data`, `meta: {page, page_size, total, total_pages}`,
and `organizations: [{id, name, can_read, can_post, can_manage}]` for the editor.
Each job includes `can_manage` and a server-owned `synthetic` label.

## Writes

Create requires `organization_id`, `title`, `description`, `location`,
`industry`, `employment_type`, and `work_mode`. Optional fields are
`requirements` (up to 40 skill strings), `highlights` (up to 20 responsibility
strings), `salary_min`, `salary_max`, `currency` (default IDR), and `status`
(default draft). Both salaries can be omitted. Maximum must not be below minimum.

Organization and creator are assigned after permission checks and cannot be
changed by an update. API callers cannot set `synthetic` or publication timestamps.
Validation failures return 422 with `error: "validation_failed"` and field errors.

The UI is available at `/jobs` and the dashboard's vacancies destination.
The client uses Session refresh/retry, debounced server search, pagination,
fresh detail fetches, an employer editor, and confirmed deletion.

Listings start as drafts. The current editor permits an authorized employer to
explicitly set a listing active or expired; first publication receives a
server-generated timestamp. No automatic approval queue is included in this
listing slice. The open PRD publication-policy question has not been recorded
as a team decision.

The former hard-coded board data is preserved under
`apps/stellar_fe/test/fixtures/legacy_job_samples.dart` as clearly labeled
synthetic fixtures and is never imported by production UI. No synthetic jobs
are inserted into a database automatically.

## Verification

Backend checks use the pinned Elixir/OTP image and an isolated ParadeDB test
database. `mix precommit` passes, including 17 new HTTP tests for browsing,
scoping, filters, pagination, validation, employer writes, timestamps and admin
access. The migration was applied, rolled back and reapplied in that test DB.

Seven Flutter API/widget tests cover the API contract, search/detail loading,
create/delete interaction and error/empty states. Desktop (1200px) and mobile
(390px) previews were rendered and inspected with real fonts; no layout overflow
remained. The broader Flutter VM run passed 50 tests but the pre-existing
`_tmp_register_flow_test.dart` cannot compile its browser-only Google sign-in
imports on the VM. That unrelated test was left unchanged.

Flutter analysis, formatting of changed Dart files, and the production web build
also pass. Local verification used an isolated Flutter 3.47.9 SDK because the
installed SDK's Dart 3.11 is below the project's existing `^3.12.0` requirement;
project dependency locks and SDK requirements were preserved.

Publication policy and final retention/removal of legacy fixtures remain subject
to the open PRD questions presented to the user during this work.
