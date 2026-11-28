# Public vacancy access — 2026-11-18

Decision D22 makes active vacancies public across organizations. Visitors can
open the landing page's **Explore jobs** button or go directly to
<http://localhost:8081/#/jobs>, search and filter, and open full details. The
public route also bypasses the onboarding gate. A visitor sees **Sign in to apply**;
a registered candidate can apply without organization membership or provisioning.

The authenticated overview uses the same public vacancy collection and keeps
profile facts private. Drafts and expired listings remain limited to authorized
posters/managers. Management scope requires login; job writes, applicant profiles,
hiring history and chats retain their existing access checks. Optional supplied
credentials are verified, so an invalid/refresh token is not treated as a valid
employer session.

## Validation

- `mix precommit`: 286 tests and 7 doctests, zero failures.
- Targeted Flutter API/widget suite: 27 passed; the 16 vacancy/overview tests were
  repeated after the final UI refactor and passed.
- Targeted Flutter analysis: no issues. Production Flutter web build succeeded.
- Docker Playwright suite: 10 scenarios passed, including guest navigation from
  the landing page, direct links and reloads, search/detail viewing on desktop
  and mobile, the login prompt before application/profile requests, and a new
  account applying with no memberships. Existing employer editing, the full
  hiring sequence, live chat and concurrent writes also passed.

Backend regressions cover public reads, cross-organization discovery, new
unprovisioned accounts, inactive listing privacy, management permissions,
invalid/refresh credentials, protected writes and applications, and the overview's
global active counts with private caller-owned profile facts.

Both local Docker images were rebuilt and restarted. The 12 persistent manual
demo vacancies remain available; temporary automated-test accounts and records
were removed. Repeat the Docker suite using the setup/cleanup commands in the
[earlier verification guide](jobs-hiring-2026-11-17.md#repeat-the-docker-checks).
The opt-in fixture now includes an additional newcomer with no organization role.

This updates the discovery behavior described in the November 17 report; its
earlier organization-membership requirement is superseded by D22. Existing
unrelated unused-variable/Ash notification warnings remain in the umbrella test
output. External PDF storage and non-Chromium browsers were not exercised.
