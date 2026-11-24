# CV categories and relevant job listings

Updated 2026-11-23 following decision D23. The normal listing is sorted by the
candidate's saved CV. There is no separate ranked-results list.

## Flow

1. Sign in and consent to CV processing. Upload a PDF up to 10 MB.
2. The backend fingerprints the bytes and scopes the version to the account.
   If those bytes were previously extracted and saved, reuse the structured CV.
   Otherwise the PDF service extracts skills, experience and education once.
3. Review and correct the comma-separated skills, then select **Use this CV for job listings**. The backend
   derives role categories locally and saves the facts, classifier version and
   content hash in the existing `rag_cv_analyses.payload` column.
4. The regular jobs list switches to **Most relevant to my CV**. It uses the
   saved CV on future visits, including after the PDF service restarts/expires.
5. A changed PDF gets a new version. The most recently saved CV is used by
   default. Changing extracted facts invalidates its cached category profile.

Journey update, 2026-11-24: accepting an owned analysis also updates the private
candidate CV facts in the same transaction. `/api/me/cv` and future application
snapshots therefore use the reviewed skills/experience/education. Candidates may
later correct `skills` through the CV editor; listing relevance, saved-CV rematch
and Apply suggestions all honor the corrections without re-extracting the PDF.
An explicit historical CV lookup only receives the current override if its CV ID
matches. Existing sent applications retain their original snapshot.

The upload panel remembers the current extraction ID per account on the device,
resumes status polling after navigation/reload, and offers a new upload when the
temporary extraction expires. Review edits are submitted as optional
`reviewed_skills` with `extraction_id` to `POST /api/rag/analyses` (at most 100
strings, each at most 100 characters). The backend checks extraction ownership
before applying corrections. Keyword fallback is labeled as basic text extraction.

The fullstack Compose starts `josjob_ragpdf`, including qpdf/pdftotext, and points
the backend at `http://josjob_ragpdf:4010` using the shared local API token.
Provider order remains configurable through `RAGPDF_PROVIDER_ORDER`; automated
local verification explicitly uses `keyword` without sending CVs to a live AI API.

## No AI calls while browsing or comparing jobs

Normal ranking does not embed the CV, jobs or courses and does not call an LLM.
AI tokens may be consumed during the initial PDF extraction only. Duplicate
uploads use the account-scoped stored extraction after it has been saved; prior
to saving, the PDF service's version-based idempotency key avoids duplicate work
while that extraction remains in its in-memory queue.

`CategoryRanking` uses a versioned local taxonomy covering software roles,
design, marketing, sales, finance, people, support, hospitality, logistics,
healthcare and education. It infers CV categories from extracted skills and
experience titles. Job tags use existing titles, falling back to required
skills when a title is unrecognized. Employers do not need an AI analysis of
job descriptions. No new taxonomy table or database migration is required.

Ordering is deterministic:

1. Same category, then related category family, then unknown category, then
   unrelated roles. An unclassified CV falls back to skill matching for all roles.
2. Within a group, fraction of required skills found in the CV (alias-aware).
3. Recency, followed by job ID for stable ties.

Only plausible or unknown roles need detailed skill comparison. Unrelated
roles remain in the listing with a **Less relevant** label, a null skill score
and no asserted skill gaps (their skills were not assessed). Category hints and
skill counts are not hiring probabilities. Unknown skills remain usable through
exact/alias matching; category coverage is deliberately conservative.

## API

All CV data remains account-scoped. Existing public newest/salary browsing and
employer permissions remain available.

- `POST /api/rag/cv/extractions`: multipart `file`, `consent=true`. The server
  assigns `cv_pdf_<sha256>` as the CV version and a default idempotency key.
  A saved duplicate returns a completed cached extraction without calling AI.
- `GET /api/rag/cv/extractions/:id`: owner-only status. Saved fingerprint IDs
  are served from the database; temporary service job IDs use the private proxy.
- `POST /api/rag/analyses`: first use `{ "extraction_id": "..." }`; subsequent
  refreshes can use `{ "cv_id": "..." }` with no extraction-service request.
  Returns `method: "category_skill"`, `profile`, `semantic: false` and
  `scoring.external_ai_calls: 0`. Structured-input support is retained.
- `GET /api/rag/analyses/:cv_id`: existing owner-scoped snapshot.
- `GET /api/jobs?sort=relevance`: authenticated, uses the latest saved CV.
  Optional `cv_id` selects an owned version. All existing browse filters apply.
  Sorting occurs across all filtered active jobs **before pagination**. Each job
  has optional `relevance` metadata (label, categories, matched/missing skills).
  Metadata includes `relevance_status`, `cv_id`, `cv_categories`, and `method`.
  When no CV is saved, newest jobs remain visible with status `cv_required`.
  Explicit unknown/foreign CV IDs return 404; anonymous relevance requests 401.

The analysis-snapshot endpoint still limits its response to 50 jobs from its
250-candidate budget. The normal relevance-sorted listing has no such truncation;
all filtered active jobs remain accessible through ordinary pagination.

## Deployment and limits

Deploy the backend/PDF service/frontend together. The private PDF response must
include `user_id` so ownership can be checked. Raw uploads are not attached as a
saved resume document by this flow; saved structured facts are reusable.

Raw extraction queue state remains in memory. Once saved, structured facts and
categories survive service restarts. If processing is incomplete when the service
expires/restarts, upload again. PDF deletion/privacy lifecycle work remains
separate from document selection.

The initial category taxonomy is a local rule set, not a universal occupation
ontology. Job tags currently derive from metadata locally during requests.
Relevance ordering loads the filtered catalog into memory; for a much larger
catalog, materialize/index role tags and move category/skill ordering into SQL.
The legacy indexing utilities now default to local vectors too; job create/update
no longer queue embedding requests. Existing stored vectors are not required.

## Verification

Tests cover no embedding/vector-store calls during repeated ranking, category
families, skill aliases, unknown-category fallback, category cache invalidation,
all jobs remaining visible, sorting before pagination, existing filters, private
CV access, saved reuse after extraction expiry and duplicate-PDF reuse.
Flutter tests cover upload consent, the saved-CV callback, and relevance labels
inside the existing listing. Automated provider tests use fakes, not live keys.

The Vacancies panel restores the saved CV from the listing response's `cv_id`
and categories. Returning users see “Your CV is ready”; changing the CV opens
the consent/upload form explicitly. Loading and lookup failures have separate
states, and changing listing sort retains the saved profile. Restoring this
panel makes no extraction or analysis requests. Verified all six demo accounts
after a full browser reload; Flutter analysis and 15 targeted tests passed.

Validation on 2026-11-23: `mix precommit` passed (all umbrella tests, including
118 RAG tests and 210 web tests); Flutter analysis passed and 18 targeted
frontend tests passed. No live AI-provider calls were needed for these checks.
