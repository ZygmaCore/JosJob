# Vacancy and hiring verification — 2026-11-17

Verified the working tree based on `96046ef800d205082501e3fceeb5192cd575255b`.
The local Docker stack served Flutter at `http://localhost:8081` and Phoenix at
`http://localhost:4000`, backed by its persistent PostgreSQL database.

## Results

| Check | Result |
| --- | --- |
| `mix precommit` (compile, dependency cleanup, format, umbrella tests) | 285 tests and 7 doctests passed |
| Flutter vacancy, overview, application, chat and CV API/widget tests | 31 passed |
| Playwright against Docker: seven API scenarios and two browser journeys | 9 passed |
| Temporary QA data cleanup | Completed; services left running |

### Coverage

- Vacancies: employer create/edit, draft publication, expiration and deletion;
  server validation; ignored forged ownership/publication fields; organization
  isolation and candidate write restrictions.
- Discovery: search, location/industry filters, all five employment types, all
  three work modes, salary/currency filtering and sorting, pagination, invalid
  filters, loading/error/empty states and mobile layout.
- Applications: explicit consent, saved profile and selected owned PDF snapshot,
  immutable snapshot after CV changes, duplicate/self-application protection,
  candidate privacy, employer job filtering, 25+1 pagination and stage counts.
- Hiring: Applied → Reviewing → Interview → Offer → Hired; shared notes and
  history; future interview dates including JavaScript millisecond timestamps;
  rejection and withdrawal from every active stage; forbidden stage jumps;
  stale updates; terminal stages cannot reopen; closed chats remain readable.
- Concurrency against real PostgreSQL connections: duplicate submissions yield
  one creation and one conflict; competing hiring updates append one event;
  eight simultaneous deletion/submission attempts preserve consistent results.
- Browser journeys: employer creates a draft, edits and publishes it, then deletes
  the unused listing; candidate applies with consent, employer opens the applicant,
  sends a chat message observed on the candidate's live WebSocket, and advances
  through all hiring stages with notes. The candidate checks the closed chat at
  a 390×844 viewport.
- Existing channel tests also cover private application/coaching conversations,
  cancelled bookings, idempotent sends, message limits/history pagination,
  expired sockets and revoked hiring membership.

## Fixed during verification

Concurrent vacancy deletion and application submission could return HTTP 500:
the delete operation checked for applications before a submission committed.
`JosjobJob.Listings.delete/2` now locks the same job row used by submission,
checks applications inside that transaction, and sends Ash notifications after
the transaction. Valid outcomes are application 201/delete 409 or application
404/delete 204. The new Docker regression reproduces the original failure and
passes with the fix.

Added six backend edge-case tests in `hiring_edges_controller_test.exs` and the
opt-in Docker suite `e2e/tests/jobs-hiring.spec.ts`.

## Repeat the Docker checks

Start the full local stack, install the `e2e` package dependencies with `npm ci`,
and install Playwright Chromium with `npx playwright install chromium` from
`e2e`. Run the following PowerShell commands from the repository root. If Docker
is absent from PATH, use Docker Desktop's full executable path for `$docker`.

```powershell
$docker = 'docker.exe'
& $docker --context desktop-linux cp e2e/fixtures/jobs_hiring.exs josjob-josjob_be-1:/tmp/jobs_hiring.exs
& $docker --context desktop-linux exec josjob-josjob_be-1 bin/josjob rpc 'Code.eval_file(~s(/tmp/jobs_hiring.exs))'
if ($LASTEXITCODE -ne 0) { throw 'QA fixture creation failed' }

$manifest = Join-Path ([IO.Path]::GetTempPath()) 'josjob-jobs-hiring-qa.json'
try {
  & $docker --context desktop-linux cp josjob-josjob_be-1:/tmp/jobs-hiring-qa.json $manifest
  $env:JOBS_HIRING_FIXTURE = $manifest
  $env:BASE_URL = 'http://localhost:8081'
  $env:API_BASE_URL = 'http://localhost:4000'
  Push-Location e2e
  try { npx playwright test tests/jobs-hiring.spec.ts --workers=1 --project=chromium }
  finally { Pop-Location }
} finally {
  & $docker --context desktop-linux exec josjob-josjob_be-1 bin/josjob rpc 'Code.eval_string(File.read!(~s(/tmp/jobs_hiring.exs)), jobs_qa_action: :cleanup)'
  Remove-Item -LiteralPath $manifest -ErrorAction SilentlyContinue
  Remove-Item Env:JOBS_HIRING_FIXTURE -ErrorAction SilentlyContinue
}
```

An existing local Chromium can be selected with
`PLAYWRIGHT_CHROMIUM_EXECUTABLE`. The suite refuses non-local service URLs and
skips when no fixture manifest is supplied. Use one worker as shown. Create a
fresh fixture for each complete run; the pagination case expects isolated users.
The fixture refuses to overwrite an existing manifest. Cleanup verifies its
synthetic organization names and deletes only the manifest's organizations,
users and dependent records. Keep its container manifest/script until cleanup
finishes; recopy them if recreating the backend container mid-run.

## Limits and existing diagnostics

These checks use explicitly marked synthetic candidates/vacancies through real
local application/database flows. They do not validate real employer openings,
production infrastructure, external PDF object-storage upload/download, or a
large-scale load test. PDF ownership, selection and snapshots are tested using
document metadata. Browser checks ran in Chromium; Safari and Firefox were not
run. Existing unrelated unused-variable and Ash invitation notification warnings
remain in the umbrella suite; it exits successfully with zero test failures.
