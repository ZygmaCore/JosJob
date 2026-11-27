# Job skill courses

An explicit local/demo seed supplies 20 free public introductory courses covering
all 62 requirement tags in the 20 active CV-demo jobs. Each course now includes
three original lessons in two modules: concepts, guided practice and a knowledge
check. This supersedes the earlier outline-only/class-based seed.

Run after migrations and the base organization seed:

```sh
MIX_ENV=dev mix run apps/josjob/priv/repo/job_skill_course_seeds.exs
```

Definitions and server-side quiz keys live in
`apps/josjob_lrn/priv/demo/job_skill_courses.json`. The seed defaults to the existing
Atveti organization; `JosjobLrn.JobSkillSeeds.seed(organization_id: id)` selects
another organization explicitly. It never creates accounts, changes CV/job data
or invokes an AI service, and is not called automatically on startup.

Courses/sections remain marked `[Skill Demo]`. These are short introductory
courses, not accredited training or a promise of professional mastery. Their
reading and practice content is original. Exercises are self-assessed. Quizzes
are graded on the server at an 80% pass mark; no certificate is issued.

New seed runs no longer create placeholder classes. Existing legacy classes and
enrollments remain intact. Only unedited, previously generated outline
 descriptions are upgraded; existing course/lesson edits and prices are preserved.
A transaction serializes repeat runs per organization and lesson positions are
unique, so reruns do not duplicate curriculum. Renaming marked course/section
names changes their natural keys; keep these names when rerunning.

Candidates open a course from job skill-gap suggestions or Explore, start
learning directly and resume it from My Courses or Overview. See the
[curriculum API](api/course-curriculum.md) for access, progress and grading.

Previous live matching verification confirmed 62/62 tags were covered and all six
CV demo accounts received complete course coverage across 114 job-gap checks.
Curriculum verification additionally checks ordered access, quiz answer-key
privacy, failed-quiz retries, paid access and persisted account-specific progress.
