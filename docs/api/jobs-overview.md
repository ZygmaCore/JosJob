# Jobs overview

`GET /api/me/jobs-overview` requires a Bearer token. The dashboard's Jobs →
Overview calls this endpoint rather than rendering sample matches, applications,
interviews or a profile-strength score.

The response is `{data: {stats, jobs, organizations, profile, capabilities}}`.

| Field | Meaning |
| --- | --- |
| `stats.available_jobs` | All public active listings across organizations |
| `stats.remote_jobs` | Active accessible listings with `work_mode: remote` |
| `stats.full_time_jobs` | Active accessible listings with `employment_type: full-time` |
| `stats.published_last_7_days` | Active accessible listings published within the rolling last 7×24 hours, excluding future and missing timestamps |
| `jobs` | Latest six active listings, using the same serializer and ordering as the jobs board |
| `organizations` | Caller-authorized job organizations and existing management capabilities |
| `profile` | The caller's persisted onboarding progress, saved skills, work history/education record counts and certificate record count |
| `capabilities` | `matching: false`, `applications: true`, `interviews: true` |

Listing counts and previews use the public active collection (D22, 2026-11-18),
including for accounts without memberships. Drafts and expired listings are
excluded. `organizations` describes the caller's own access and management
capabilities. The endpoint remains authenticated because it also contains private
profile facts. Query parameters cannot select another user's profile or turn
this summary into a management scope. Counts cover the whole public collection,
not only the six-item preview.

Profile skills and meaningful work/education records are read from the caller's
saved onboarding answers. Skills are trimmed and deduplicated without case;
up to eight labels are included, with the full count retained. Certificate records
come from the caller's [certificate API domain](certificates.md), including actual
onboarding certifications. Counts do not imply verification, and saved onboarding
progress is not an AI profile-quality score.

The Flutter view supports loading, failure/retry, empty states, manual refresh,
browsing vacancies and opening fresh job details through the existing detail
flow. Closing details or returning from onboarding refetches the summary. Salary
and synthetic-data labels come from stored listing data. No currencies are
converted, no application totals are invented, and no open-to-work status is
assumed. Personalized matching remains unavailable. The
[CV destination has its own persisted data](curriculum-vitae.md), and
[Applications and hiring](applications-and-chat.md) use their own private endpoints;
application totals are not included in this overview.

Backend tests cover authentication, tenant/permission isolation, active-only
counts, preview limits, publication windows, superusers and private profile data.
Flutter tests cover the contract, failure handling, callbacks/refetch, empty
accounts and mobile layout, alongside existing board/detail regressions.
