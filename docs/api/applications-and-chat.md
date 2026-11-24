# Applications, hiring and shared chat

Journey update (2026-11-24): Apply previews the same reviewed CV facts used by
matching, offers Edit CV profile & skills, and refreshes suggestions on return.
The cover letter is saved locally by account and job; consent is requested again
after profile editing and is never persisted. Course suggestions open a sheet
with Back to application, enrollment feedback and authorized learning materials.
Successful submissions clear the draft and open status/next-step details;
duplicate submissions open the candidate's existing application. Job detail
returns only the current candidate's `my_application` reference and offers View
my application. Existing application snapshots remain immutable when the CV changes.

The Applications destination now reads persisted records, not the former sample
application history. Any signed-in candidate can submit to a public active listing
without organization membership (D22, 2026-11-18). Browsing listings and details
does not require login. Employers still use `jobs:manage` in the listing's
organization to review candidates. Submitted profiles and conversations stay private.

## Hiring

The main sequence is **Applied → Reviewing → Interview → Offer → Hired**.
Hiring teams may reject an active application; candidates may withdraw their own.
Stages cannot be skipped or reopened. An interview time is optional when advancing
to Interview and must be in the future. Notes and the immutable stage history are
visible to both sides; there are no private employer notes in this implementation.

| Method and route | Behavior |
| --- | --- |
| `POST /api/jobs/:job_id/applications` | Submit `consent: true` and optional `cover_letter` (4,000 characters) |
| `GET /api/applications` | Own applications; `scope=hiring` selects managed organizations |
| `GET /api/applications/:id` | Submitted profile, cover letter, allowed next stages and history |
| `PATCH /api/applications/:id` | `status`, `expected_status`, optional `note` (2,000 characters) and ISO8601 `interview_at` |

List filters: `status`, `job_id`, `page`. Pages contain at most 25 records and
include stage counts, managed organizations and pagination metadata. Counts are
computed for the authorized scope and job filter, before the stage filter.

Submission copies the candidate's saved identity, headline, summary, skills,
education, experience and explicitly selected owned CV PDF. The form previews
these details and requires consent to share them with that employer. Unselected
documents are excluded. Later profile edits do not change the submitted snapshot.
The selected document's existing URL is preserved; storage still needs configuration
for new file uploads. Application/chat tables use Ecto schemas and the shared Repo;
existing job, profile and coaching resources continue to use Ash.

The database enforces one application per candidate/listing. Retrying submission
returns `409 already_submitted`; users open the existing application rather than
creating another. Row locks serialize submissions against listing closure and stage
changes against other stage changes. Stale `expected_status` returns `409`.
Listings with applications must be expired instead of deleted, preserving history.

## Learning suggestions when applying

`GET /api/jobs/:job_id/application-suggestions` requires Bearer authentication
and a visible active listing. It is a read-only check; it never creates an
application, enrolls the candidate, or invokes an AI/PDF provider.

`JosjobRag.ApplicationSuggestions` compares every requirement of this specific
job with the candidate's latest saved analyzed CV (`source: analyzed_cv`). If
there is no saved analysis with skills, it uses skills from their CV profile
(`source: saved_profile`). The UI names the source; the analyzed CV can differ
from the PDF selected for sharing in the application. Existing canonical skill
aliases apply, including JS/JavaScript and Postgres/PostgreSQL. Unlike discovery
ranking, comparison also runs for jobs outside the candidate's role category.

The response's `data` contains `status` (`gap`, `matched`, `cv_required`, or
`no_requirements`), `source`, `matched_skills`, `missing_skills`, `courses`, and
`uncovered_skills`. Empty CV skills return `cv_required`, never a claim that the
candidate lacks every skill. Recommended courses cover at least one missing
skill and come from the active catalog visible to this candidate. Each entry
contains catalog summary fields, `matched_skills`, and a nullable `class_id`.
Class IDs/counts obey the same organization/public visibility as catalog details.
Prices are shown, and courses without accessible scheduled classes say so.

The Apply page shows these suggestions before submission. Course buttons open
the existing catalog detail/enrollment sheet and preserve the application draft.
Skills with no matching visible course have an explicit empty message. Loading,
missing CV skills, gaps, and recommendation errors never prevent submission;
errors offer retry independently of the saved-profile preview and sharing consent.

Coverage: `application_suggestions_controller_test.exs` (source/owner scoping,
course/class visibility, aliases and application independence) and
`application_suggestions_test.dart` (mobile UI, course navigation, empty states,
loading, retry and submission despite a skill gap).
The opt-in `e2e/tests/application-suggestions.spec.ts` exercises the running local
API with the CV demo dataset and a temporary SQL course/class fixture. All eight
controller tests, ten live HTTP tests, and the umbrella precommit checks passed
in Docker on 2026-11-24; see [verification and repeat commands](../verification/application-suggestions-2026-11-24.md).

## Shared chat

Both chat types use `ChatPage` / `ChatPanel`: the same Poppins typography,
`AppColors` palette, bubbles, timestamps, empty/error states, composer and retry
behavior. Hiring chat opens from application details; coaching chat opens from an
appointment for either participant. Coaching messages do not require configured
video credentials or a currently active call window.

| Method and route | Behavior |
| --- | --- |
| `GET /api/chats/:kind/:id/messages` | Up to 50 messages in chronological order, thread metadata and `next_before` |
| `POST /api/chats/:kind/:id/messages` | Persist `body` and a stable client-generated `client_id` |
| Channel `chat:application:<id>` or `chat:coaching:<id>` | Authenticated live `message_created` delivery |

`kind` is `application` or `coaching`; `id` is the application/booking UUID.
Older history uses `before=<message-id>`. The sender is taken from authentication,
never the request. Empty messages, messages over 4,000 characters and invalid
client identifiers are rejected. Identical retries with the same client ID return
the existing message. Reusing a key with different content/context returns `409`.
There is a per-sender rate limit of 30 new messages per minute.

Application participants are the candidate and currently authorized hiring team.
Coaching participants are the booked learner and coach; unrelated users, including
platform administrators, cannot read coaching chat. Suspended coach profiles and
cancelled bookings are read-only. Completed coaching bookings retain messaging.
Hired, rejected and withdrawn applications retain read-only chat history.

The server rechecks access on every REST request and before every live delivery.
Revoked hiring memberships lose access, and channel lifetime is bounded by the
JWT expiry. The client refreshes through `Session.runAuthed`, polls as a fallback,
merges messages by ID and retains the draft and idempotency key after send failures.
There are no attachments, read receipts, push notifications or global inbox yet.

## Local verification

Backend coverage lives in `application_controller_test.exs` and
`chat_controller_test.exs`, including snapshots, all stages, invalid transitions,
tenant separation, history pagination, retries, coaching cancellation and channel
revocation. Flutter coverage lives in `workflow_api_test.dart`,
`applications_view_test.dart` and `chat_view_test.dart`.

Tests use synthetic fixtures. No real applicants or employers are fabricated or
imported into the local database. Use posted listings and registered accounts to
exercise real persisted applications.
