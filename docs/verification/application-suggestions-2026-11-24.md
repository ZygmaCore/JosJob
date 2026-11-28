# Application learning suggestions: Docker/API verification

Verified on 2026-11-24 against checkout
`fa8be2cfafa2a37eeeff05bd34dda199dc4c282b` plus the application-suggestion changes.
Both local application images were rebuilt and the existing Compose services
recreated. PostgreSQL's existing volume was retained.

| Check | Result |
| --- | --- |
| `mix precommit` in Linux, using the checkout's locked dependencies | 421 tests and 7 doctests, zero failures |
| Focused application-suggestion controller suite | 8 tests, zero failures |
| Playwright HTTP requests against the updated running API | 10 tests, zero failures |
| Backend `http://localhost:4000/` | HTTP 200 |
| Frontend `http://localhost:8081/` | HTTP 200; container healthy |

Controller coverage includes profile-skill fallback, analyzed-CV ownership,
cross-category skill checks, canonical aliases, missing/complete CV skills,
absent requirements, inactive/private courses, organization-scoped class IDs and
counts, real course recommendations, and applying despite a gap.

The HTTP suite checks all six seeded CV profiles, exact matches and missing
skills, authentication, cross-account CV privacy, inaccessible draft/expired
jobs, and a real public SQL course/class returned for a missing SQL skill.
The course's catalog detail was accessible with the same candidate token, with
the expected class ID, class count, price, and unenrolled state.

The current Docker database initially contained none of the CV demo accounts.
The explicit `JosjobRag.DemoSeeds.seed/0` entry point added its marked synthetic
dataset: six candidates, an employer, and 22 jobs (20 active). These demo records
remain available for manual testing; see [accounts and expected matches](../cv-relevance-demo.md).
The temporary SQL course, class and section were removed afterward, after
confirming the class had no enrollments. Automated backend fixtures used the
separate `josjob_test` database and SQL Sandbox. No AI-provider calls were needed.

The updated authentication dependency required `sensitive?: true` on the
existing Google OAuth token argument. This one-line metadata fix allowed
`compile --warnings-as-errors` to pass and keeps the token response redacted.

## Repeat the live checks

Run from the repository root with the local stack and CV demo dataset available.
Use Docker Desktop's CLI path if `docker` is absent from PATH. The API test suite
refuses non-local API hosts. The temporary fixture must be cleaned even if tests fail.

```powershell
$docker = 'C:/Users/LOQ/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe'
& $docker --context desktop-linux cp e2e/fixtures/application_suggestion_course.exs josjob-josjob_be-1:/tmp/application_suggestion_course.exs
& $docker --context desktop-linux exec josjob-josjob_be-1 bin/josjob rpc 'Code.eval_file(~s(/tmp/application_suggestion_course.exs))'
if ($LASTEXITCODE -ne 0) { throw 'Course fixture creation failed' }

$manifest = Join-Path ([IO.Path]::GetTempPath()) 'application-suggestion-course-qa.json'
try {
  & $docker --context desktop-linux cp josjob-josjob_be-1:/tmp/application-suggestion-course-qa.json $manifest
  $env:APPLICATION_SUGGESTIONS_API = '1'
  $env:APPLICATION_SUGGESTIONS_COURSE_FIXTURE = $manifest
  $env:API_BASE_URL = 'http://localhost:4000'
  Push-Location e2e
  try {
    npx playwright test tests/application-suggestions.spec.ts --workers=1 --project=chromium
    if ($LASTEXITCODE -ne 0) { throw 'Live API checks failed' }
  } finally { Pop-Location }
} finally {
  & $docker --context desktop-linux exec josjob-josjob_be-1 bin/josjob rpc 'Code.eval_string(File.read!(~s(/tmp/application_suggestion_course.exs)), suggestion_qa_action: :cleanup)'
  if ($LASTEXITCODE -ne 0) { throw 'Temporary course cleanup failed' }
  Remove-Item -LiteralPath $manifest -ErrorAction SilentlyContinue
  Remove-Item Env:APPLICATION_SUGGESTIONS_API -ErrorAction SilentlyContinue
  Remove-Item Env:APPLICATION_SUGGESTIONS_COURSE_FIXTURE -ErrorAction SilentlyContinue
}
```

`mix precommit` requires a configured Linux/Elixir workspace with PostgreSQL and
the native dependencies. Native Windows compilation is unsuitable for the
project's xberg NIF. Tests here used Elixir 1.19.5/OTP 27 in a temporary Docker
build container, which was removed after verification.
