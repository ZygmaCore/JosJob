# Curriculum Vitae

The Jobs → Curriculum Vitae screen reads the authenticated candidate's account,
saved onboarding background, certificates and explicitly attached PDF. All
endpoints require a Bearer token and always use the caller, including superusers.

| Method/path | Behavior |
| --- | --- |
| GET `/api/me/cv` | Own identity, saved CV presentation, background, certificates, owned PDF choices and selected resume |
| PATCH `/api/me/cv` | Save optional `headline` (up to 200 chars), `summary` (up to 4000), and `resume_document_id` |

The response is `{data: {identity, headline, summary, skills, experience,
education, certificates, pdf_documents, resume_document}}`.

Identity uses the account's name/email. Phone uses the saved onboarding value
when present, otherwise the registration phone. Location uses the saved country,
otherwise the registration address. Unknown details remain empty. Background
comes from `Profile.answers`; work/education records and periods are normalized,
skills trimmed and deduplicated without case. Year-only dates stay year-only;
missing end dates do not invent a current employer or a duration. Background is
read-only in this view. Certificates reuse [the certificate domain](certificates.md),
with self-reported/onboarding and expiry labels rather than verification claims.

`JosjobJob.CvProfile` stores only presentation fields and the explicit PDF choice.
It uses a unique owner row and a nullable document foreign key. Updates serialize
on the owner user row. Onboarding snapshots cannot overwrite these fields, and
CV saves never replace onboarding answers. Omitted fields are preserved; blank
text/null clears presentation fields, and null detaches the PDF. User, email,
roles, background and certification fields sent to this PATCH are ignored.

PDF choices are standalone `application/pdf` documents owned by the caller, with
absolute HTTP/HTTPS URLs without embedded credentials. Shared, organization,
course and foreign-owner documents are not automatically treated as the user's
resume. A PDF becomes the resume only after explicit selection. Ownership/type
are rechecked on every read, including after later document changes. Deleting
the document nulls the reference; detaching preserves the underlying document.
Document-library sharing/access rules and storage URLs still apply to the file.
Metadata and declared MIME type do not establish document authenticity.

The screen supports loading/retry/refresh, empty accounts, persisted headline and
summary editing, PDF selection/open/detach, and the real certificate management
flow. It does not generate a PDF from profile facts, upload a new file, run CV
analysis, invent a biography, or display profile-strength scores. Opening a PDF
uses the already-stored document URL on web. An account without an attached PDF
has no Open PDF action. New file uploads and CV analysis remain separate work.

Tests cover account isolation, forged ownership fields, metadata persistence,
preservation of onboarding, malformed background, date precision, invalid fields,
PDF ownership/type/URL restrictions and deleted references, plus Flutter parsing,
editing/selection/detach, certificate navigation, mobile layout and error handling.
