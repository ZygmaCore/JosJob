# Candidate navigation and learning UX

Implemented 2026-11-27, based on commit `61fadba`.

- Ask AI is available from the dashboard top bar (desktop button / mobile icon).
  The public landing page and its mobile menu do not expose the assistant. The
  existing assistant conversation and service endpoint remain unchanged.
- The candidate dashboard uses stable global destinations: Home, Jobs, My
  applications, Learning, Coaching, Profile & CV. Desktop exposes all six; mobile
  keeps Jobs, My applications, Learning and Profile & CV in the bottom bar and all
  six in the drawer. Organization management retains its own dashboard.
- Learning has My learning and Course catalog sections. Existing `view=learn`
  (`courses`, `my-courses`, `certificates`, `live-coaching`) and `view=jobs`
  (`vacancies`, `applications`, `curriculum-vitae`) links still resolve.
- Apply shows the shared profile, cover letter and explicit sharing consent before
  a collapsed optional learning section. Submit stays in a sticky footer. Learning
  is never a prerequisite for applying. Existing account/job drafts are preserved;
  returning refreshes the profile and resets consent only if it changed.
- `/courses/:id` is a full course detail page with syllabus and a sticky
  Start learning / Continue learning / View course results action. Paid courses
  retain their enrollment/payment flow. `/learn/:id` retains sequential progress.
- Course and study URLs carry a validated local `return_to`. Completion prioritizes
  Back to application/job when entered from that context. An existing Apply route
  stays alive; after reload the same named route restores its saved draft.
- Completed courses open a results page, earned skill tags and certificate status.
  Review lessons explicitly enters review mode; opening results never immediately
  presents the final quiz again. The results page remains available after reload.
- Certificate confirmation shows the course and exact CV name, requires an
  unchecked explicit confirmation, and has Not now / Issue certificate actions.
  Correct name in CV opens a focused name editor; after saving, confirmation reloads
  the current name. Existing stale-name rejection and immutable per-certificate
  server/database locks are unchanged.
- Profile certificates separate Course certificates (pending or issued) from
  Additional certificates. Manual Add is only available in Additional certificates.
- Coaching opens the directory. Coach workspace is opt-in from Profile & CV account
  tools at `/coaching/workspace`; coach publication and admin review permissions
  remain unchanged. Documents are also an account tool rather than a global icon.

Verification: `mix precommit` passed (including 234 web tests and 121 RAG tests).
All 138 Flutter tests passed, including optional learning without blocking Apply,
certificate grouping, explicit name consent, completed-course review and safe
return navigation. Changed Dart feature files are checked separately because the
legacy landing library has existing unused-element warnings.

Two additional layout regressions passed at 390 and 1440px after correcting a
course footer that consumed the body height. Local release browser checks
inspected course details/syllabus at 320, 390 and 1440px, stable desktop navigation,
mobile Apply with optional learning, contextual course completion, focused name
correction, fresh confirmation, locked issuance, draft restoration after reload,
coach directory/workspace separation, and both certificate groups. The isolated
QA learner and its test-only progress/award were deleted afterward; existing
learner records were preserved. Preview: `http://localhost:8081/`.
