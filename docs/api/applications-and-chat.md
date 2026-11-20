# Applications, hiring and shared chat

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
