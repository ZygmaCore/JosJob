# Learn overview API

`GET /api/me/learning-overview` requires a Bearer token. `scope=learner`
is the default; `scope=organization` requests the permitted organization summary.
Other scope values return 400. The Flutter Learn overview uses this endpoint;
course details and enrollment continue to use the existing catalog and class APIs.

The response is `{data: {scope, stats, enrollments, courses, upcoming_sessions,
members, completion}}`. Each preview contains at most six records; counts cover
the full authorized dataset, not just the preview.

- Learner totals: `active_enrollments`, `completed_enrollments`,
  `available_courses`, and `upcoming_sessions`. Enrollments belong to the
  authenticated user, regardless of supplied user IDs. Catalog visibility matches
  the existing API: active public courses plus courses shared with active member
  organizations. The course preview excludes previously enrolled courses and is
  sorted by title; it is catalog discovery, not an AI recommendation.
- Organization totals additionally include `members`. An active membership must
  grant read or manage access to **members, courses, and enrollments in the same
  organization**. Platform superusers may summarize all organizations. An empty
  authorized organization set returns 403. Counts and previews never expand to
  another organization merely because the caller belongs to it.
- Team completion counts enrollments in classes belonging to the same authorized
  organizations as the team member's active memberships. Course completion counts
  all participants in that organization's classes, including public-course
  students who are not organization members. These are completed class
  enrollments, not percentages of lessons watched.
- Upcoming sessions come from stored class schedules. Learners see sessions only
  for active enrollments; organizations see their classes. Invalid dates and
  past dates are excluded; duplicate sessions are collapsed. Schedules have no
  timezone, so today's UTC calendar date is the cutoff and stored wall-clock
  times are preserved without inventing an offset. Lists are ordered by date,
  start time, and class ID.

Study hours, lesson progress, ratings, certificates, growth deltas and AI
recommendations are not recorded by the current learning model and are not
fabricated. The Learn overview renders empty states and loading/retry controls,
supports manual refresh, and refetches after a course detail sheet closes.
Other dashboard destinations and the Jobs overview are outside this change.

HTTP tests cover authentication, scope validation, empty accounts, own
enrollments, catalog visibility, suspended memberships, organization permissions,
tenant isolation and preview limits. Flutter API/widget tests cover parsing,
authorization errors, retry, mobile layout, course navigation/refresh and stale
response rejection after a scope change.
