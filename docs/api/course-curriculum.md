# Self-paced course learning

2026-11-26: courses now have a self-paced learning flow inspired by the modular
academy pattern, with original introductory materials rather than copied content.
The 20 skill demo courses include 60 lessons: concepts, guided practice and a
server-graded knowledge check, grouped into two modules per course.

All endpoints require the current user's Bearer token:

| Endpoint | Behavior |
| --- | --- |
| GET `/api/catalog/courses/:id/study` | Visible course syllabus, owned enrollment/progress and unlocked content |
| POST `/api/catalog/courses/:id/study/enroll` | Enroll directly in a free course; paid courses require existing paid class access |
| POST `/api/catalog/courses/:id/study/lessons/:lesson_id/complete` | Acknowledge a reading or grade submitted quiz `answers` keyed by question id |
| GET `/api/me/course-studies` | The caller's course enrollments with persisted progress |

`JosjobLrn.Curriculum` scopes active public/organization courses before reading
or writing. Lesson bodies are not returned before enrollment or before earlier
lessons are complete. Reading completion is a learner acknowledgment; practice
is self-assessed, not reviewer-approved. Quiz answers are compared on the server;
the client receives question text/options and a score, never `correct_index`.
The pass mark is 80%, with retries. A failed quiz does not advance progress.
Progress writes lock the owned course enrollment and are idempotent. Paid access
is rechecked so removing the legacy paid enrollment also blocks course content.

Ecto schemas `CourseLesson` and `CourseStudy` use the existing Repo and learning
app. Course study enrollment is independent of class enrollment and coaching.
Legacy class data/enrollments are preserved. The demo seeder now publishes real
introductory reading/practice/quiz content and no longer creates placeholder
classes. Existing generated outline descriptions are upgraded only if unedited;
course and lesson edits remain intact on repeat runs.

Catalog and application suggestions expose `has_curriculum`. Courses with a
curriculum open `/learn/:course_id`; course overview presents self-paced learning
instead of a session list. My Courses and learner Overview show saved progress
and Continue learning. Browser reload resumes the first unfinished lesson.

Current scope: short original introductory courses with reading, self-assessed
practice and quizzes. Videos, authoring/review workflows, project submissions,
and curriculum versioning are separate work. Course completion now grants earned
skill tags without rewriting extracted CV facts. Named certificates require CV
confirmation and permanently lock the recipient name. See [course awards](course-awards.md).

Verification on 2026-11-26: `mix precommit` passed, including 232 web tests and
121 RAG tests; 19 targeted Flutter tests passed. The final mobile curriculum-sheet
interaction and course completion/resume test also passed after layout polish,
and the changed feature files passed analysis. Local release images and the
migration were deployed; all 20 courses now have three lessons each. Live API
checks exercised locked lessons, hidden answer keys, failed/passed quizzes and
saved 100% progress in My Courses/Overview. Browser checks confirmed enrollment,
33% progress after reload and desktop/mobile layouts, including the curriculum
sheet. Temporary study enrollments were removed after verification; existing
learner records and legacy class enrollments were preserved.
