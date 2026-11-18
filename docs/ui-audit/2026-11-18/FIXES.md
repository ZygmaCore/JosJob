# UI consistency fixes

Implemented against `50c2c89a3834d6be66ee51a30b28ac74d42c9e0b` on
`feat/public-jobs-hiring-chat`. The original [audit](README.md) describes the
baseline. This pass keeps the existing blue/navy palette, Poppins and JosJob mascot.

## Changes

| Audit items | Implementation |
| --- | --- |
| UI-01, UI-04, UI-06 | Shared Poppins text, app bars, button shapes and sizes, white dialog surfaces, inputs, chips and snackbar defaults in `appTheme()`. Confirmation actions identify the stage or destructive operation. |
| UI-02 | `AppBrand` provides the mascot/name lockup across login, onboarding, dashboard, jobs and catalog. Removed visible Atveti/Stellar copy from pending-account and landing surfaces. |
| UI-03, UI-05 | Consistent page-title scale; embedded catalog/vacancy views use dashboard gutters. Vacancy text fields now reuse `AppFormField`, including multiline height, field limits and server/validation errors. |
| UI-07 | Applying as a guest remembers the selected job through login reload and onboarding; successful sign-in resumes its application form. Return paths are restricted to internal feature destinations and cleared after consumption/sign-out. |
| UI-08 | Router owns browser history; dashboard view/tab/scope/stage are encoded in the URI. Job, application and chat detail routes can be reloaded directly. Existing authorization guards still resolve every named route. |
| UI-09 | A keyed content subtree and shared scroll controller preserve child state when switching between desktop and mobile shells. |
| UI-10 | Course columns derive from the available content width. Cards grow with their content; category tags use a single truncated line and actions remain inside the card. |
| UI-11, UI-12 | Removed toolbar AI/notification placeholders and the invented unread count. Login/catalog/coaching copy reflects available features. Recovery is visibly unavailable; registration states that preview Terms/Privacy are unpublished. |
| UI-13, UI-14 | Shared semantic status badges; global blue selected-chip treatment; coaching scopes now expose a selected state. Product navigation remains distinct from filters. |
| UI-15, UI-16 | Shared company avatars ignore demo suffix punctuation; employment labels and synthetic labels agree across vacancy views. Shared readable dates, local date-times with timezone, and explicit ISO currency codes. |
| UI-17 | Mobile applications replace stage-count tiles and eight filter chips with one stage selector and result count. Existing advanced vacancy filters remain collapsible. |
| UI-18 | Shared icon/title/message/action states reused by dashboard, jobs, catalog, applications, certificates and Documents. Documents failures gain an inline retry action. |
| UI-19 | Removed redundant control labels and nested toolbar/logout/menu wrappers. Course cards expose separate Save/View controls instead of a primary button surrounding another button. |
| UI-20 | Course bookmarks persist in device storage, partitioned by account. Save/remove messages and tooltips explicitly describe device-local storage. |

## Product boundaries

Course bookmarks do not sync between devices. Password recovery, published legal
documents, AI matching and configured live video remain separate product work;
this pass removes misleading claims or makes their availability explicit.
The Phoenix admin screens on port 4000 are a separate UI from Flutter web.

## Verification

- `mix precommit`: **286 tests + 7 doctests, zero failures** in the WSL backend
  checkout. Existing Ash notification and test warnings remain in the output.
- Targeted Flutter analyzer: **no issues** across the changed feature libraries,
  shared components, preferences and new regression tests.
- **61 Flutter unit/widget tests passed**, including new cold deep-link,
  startup-gate/history, auth redirect, responsive hiring filter, account-isolated
  bookmark persistence and auth-return consumption cases.
- Release web build completed and the frontend image was rebuilt/recreated in
  local Docker. Backend and PostgreSQL remain running.
- **12 Docker Chromium end-to-end checks passed**: public browsing and guest
  sign-in return, vacancy CRUD/filtering, application permissions/consent,
  concurrent operations, every hiring stage, read-only conversations, live chat,
  and dashboard resize/reload/Back/Forward. Employer form input uses keyboard
  events with frame synchronization so Flutter receives edits before submission.
- Captured **24 Chromium screenshots**, with no `pageerror` events, at
  1440×1000 and 390×844. Inspected forms, cards, hiring filters and hiring chat;
  also checked bookmark save/reload/remove in an isolated browser context.
- Browser history was explicitly checked during the startup splash as well as
  after navigation/reload. Router remains mounted while the Navigator waits for
  the SQLite bootstrap gate.
- Temporary QA organizations, users, vacancies and applications were removed
  using the guarded fixture cleanup. The manual demo organization still has
  **12 vacancies (10 active, 1 draft, 1 expired) and 6 applications**, including
  the pre-existing real-user application. Existing records were not reset.

Selected after screenshots: [course cards](after/07-course-cards-desktop.png),
[mobile vacancy form](after/21-job-editor-mobile.png),
[mobile hiring](after/23-hiring-mobile.png),
[mobile hiring chat](after/17-chat-mobile.png),
[login](after/01-login-desktop.png),
[public vacancies](after/04-public-jobs-desktop.png).

This is targeted verification, not certification of every product screen,
browser, onboarding permutation, payment or live-video state. Original audit
screenshots are retained for comparison. No AI service or live video provider
was enabled as part of this pass.
