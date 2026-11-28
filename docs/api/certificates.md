# Learner certificates

The Learn → Certificates screen reads persisted records rather than sample
awards or target recommendations. All endpoints require a Bearer token and
always use the caller's user ID, including for platform superusers.

| Method/path | Behavior |
| --- | --- |
| GET `/api/me/certificates` | Caller-owned certificate records and actual onboarding certifications |
| POST `/api/me/certificates` | Add a self-reported certificate; returns 201 and the saved record |
| PATCH `/api/me/certificates/:id` | Update a caller-owned certificate; returns the saved record |
| DELETE `/api/me/certificates/:id` | Remove a caller-owned certificate |

Writable fields: `title` and `issuer` (required, 2–200 characters),
`issued_on` and `expires_on` (optional ISO dates), `credential_id` (optional,
up to 200 characters), and `credential_url` (optional, up to 2000 characters).
Strings are trimmed; blank optional values become null. Dates cannot represent
a future issue or expiry before issue. Expired certificates can be recorded.
Credential links accept absolute HTTP/HTTPS URLs without user credentials.
An omitted field is preserved on PATCH; null clears an optional field.

Responses contain `id`, the writable fields, `source`, `editable`, `expired`,
and `recorded_period`. Manually added records have `source: self_reported`,
`editable: true`, and `expired` derived from the current UTC date. Expiry on
today's date is not yet expired. No field asserts issuer verification.
Owner, verification, source, course and status fields sent by clients are ignored.
Missing/foreign/malformed IDs return 404; invalid input returns 422.

Onboarding records are read from the caller's `Profile.answers.achievements`
with type `Certification` and a non-empty name. They have `source: onboarding`,
`editable: false`, and response-only IDs `onboarding-<index>`. Their original
month/year periods appear as `recorded_period`; an exact issue/expiry date is
not invented. Other achievements and malformed entries are excluded. This
read-only projection preserves the onboarding sync source and its unrelated
answers. These entries are not editable/deletable through the certificate API.

The Flutter screen supports loading, retry, empty states, refresh, add/edit,
confirmed deletion, expiry labels and opening credential links on web. Sample
target recommendations have been removed. No certificate is automatically
issued from an enrollment or a coaching appointment. Course certificate issuance,
PDF generation, issuer verification, uploads and recommendation/matching rules
remain outside this record-management flow.

Backend verification covers authentication on all methods, ownership, persistence,
input validation, partial updates and onboarding projection. Flutter tests cover
the API contract, malformed responses, CRUD, links, mobile layout and error retry.
