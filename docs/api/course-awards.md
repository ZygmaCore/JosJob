# Earned skills and locked certificate names

Successful course completion creates one owned `CourseAward` in the lesson
completion transaction. Its course title and skill tags are snapshots. Failed or
incomplete quizzes grant nothing. Repeated completion does not duplicate or modify
the award. Earned tags merge with editable CV skills in job ranking, skill-gap
suggestions, job details and future application snapshots. They survive CV edits
and new PDF extraction without overwriting the extracted facts. No AI calls run.

Skill grants are immediate. Named certificates require separate confirmation.
Pending course awards appear in Certificates and on the completed course page.

| Endpoint | Behavior |
| --- | --- |
| GET `/api/me/course-awards/:id` | Owned award plus the current saved CV name |
| POST `/api/me/course-awards/:id/confirm` | Requires `confirm_cv: true` and an exact `expected_name` from the preview |
| PATCH `/api/me/cv` | Corrects the CV-specific `full_name` for future certificates |

The confirmation dialog asks whether the CV is correct, displays the exact name
and explains that it will be permanently locked for this certificate. The user
may edit CV details first; confirmation remains unchecked after editing. There
is no editable certificate-name override. Server-side issuance locks the user and
award rows and rechecks current CV identity. A stale preview returns
`409 cv_name_changed`; missing confirmation returns 422; another user's award is
404. The API ignores client attempts to supply a different recipient name.

After issuance, the recipient and issuance time are immutable. Retrying returns
the same certificate even after a CV edit. The lock is per certificate, so a new
course certificate can use a newer CV name. Course-award update/deletion through
the normal certificate APIs returns 409. A database trigger independently rejects
changes to issued certificates and earned title/skill snapshots. A unique
user/course constraint prevents duplicate awards.

Certificates have source `course_completion`, issuer JosJob and a unique
`JOSJOB-<award UUID>` credential ID. Existing self-reported and onboarding records
retain their own edit rules and source labels. These are platform course-completion
records, not professional accreditation or externally reviewed project work.

Backfill grants current course tags for already completed nonempty curricula,
but does not confirm a name or issue a named certificate automatically. Until
edited, CV identity falls back to the account name. Editing the CV name does not
rewrite the account identity, previous applications or locked certificates.

Returning from course learning refreshes the Apply page's profile and gap
suggestions. Sharing consent resets only if the profile actually changed, so
new earned skills or a corrected CV name are reviewed before submission.

Verification on 2026-11-27: `mix precommit` passed, including 234 web tests and
121 RAG tests. Twenty-one targeted Flutter tests passed, and changed feature
files passed analysis. Live API/browser checks used an isolated temporary learner
to complete two courses, receive tags, reject a stale name, edit CV before
confirmation, issue the certificate and verify that a later CV edit/reload does
not rename it. Mobile screenshots were inspected. The temporary learner and its
test-only awards/progress were removed afterward; existing user records remain.
