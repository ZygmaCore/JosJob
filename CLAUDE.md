# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# Flutter frontend structure

This repo is an Elixir umbrella; the Flutter (Dart) frontend is the single
unified app `apps/stellar_fe` — one platform spanning both **Online Learning**
and **AI Job Placement**. The flow is: one platform landing → shared auth →
onboarding → a dashboard with an in-app **Learn | Jobs** switcher. (It was
previously two apps, `stellar_lrn_fe` + `stellar_job_fe`, now merged.)

The app is **UI-only — no backend wiring, no persistence**; all data is
hard-coded sample content.

## One module = one Dart `part`/`part of` library

Each page/feature is a folder under `lib/`. The folder's **entry file is the library**, holding ONLY: imports, a banner comment, `part` directives, and the public entry widget plus a few library-private shared helpers. **Every component lives in its own file** as a `part` of that library.

```
apps/stellar_fe/lib/
  main.dart                       # the ONLY file at lib/ root — MaterialApp + routes
  landing/
    landing_page_ascent.dart      # library entry: StellarLandingPage (platform landing)
    data/  shell/  spine/  sections/  widgets/
  auth/
    auth_page.dart                # library entry: LoginPage, RegisterPage
    data/  screens/  shell/  widgets/
  onboarding/
    onboarding_page.dart          # library entry: OnboardingFlow
    data/  shell/  steps/  widgets/
  dashboard/
    dashboard_page.dart           # library entry: DashboardPage (Learn|Jobs switcher, role-adaptive)
    data/  overview/  shell/  widgets/
  explore/                        # learning: course catalog (ExploreCoursePage)
  quiz/                           # learning: quizzes hub (QuizPage)
  jobs/
    jobs_page.dart                # library entry: JobsPage (AI job-placement board)
    data/  screens/  widgets/
  theme/app_theme.dart            # AppColors, Bp — shared design tokens (source of truth)
  shared/onboard_role.dart        # OnboardRole enum — shared by onboarding + dashboard
```

**Subfolder roles** (consistent across modules):
- `data/` — models, sample-data consts, helper functions/extensions (no widgets).
- `shell/` — page chrome: scaffold, top/bottom bars, sidebar, drawer, footer, section wrappers.
- `widgets/` — reusable leaf components (buttons, chips, cards, fields, `CustomPainter`s).
- screen group — the screens themselves: `sections/` (landing), `screens/` (auth, jobs), `steps/` (onboarding), `overview/` (dashboard).

## Rules when working on these apps

- Components are private (`_Foo`); only the module's entry widget is public. `part` keeps them private with no clashes against Flutter's own `Hero`/`Section`/`Logo`.
- **Add a component:** create `lib/<module>/<sub>/<name>.dart` whose first line is `part of '../<entry>.dart';` (a part file has **no imports** — the entry file's imports apply to all parts), then add a matching `part '<sub>/<name>.dart';` directive in the entry file. Keep a `StatefulWidget` + its `State`, and a widget + its `CustomPainter`, in the **same** file.
- **Design tokens:** always use `AppColors` + `Bp` from `theme/app_theme.dart`; fonts are Poppins via the `google_fonts` package. `landing_page_ascent.dart` re-exports the theme, so `import '.../landing/landing_page_ascent.dart' show AppColors, Bp` also works.
- **Verify after UI changes** (from the app dir `apps/stellar_fe`): `flutter analyze` must report **No issues found**, and `dart format lib` must be clean (**CI enforces formatting**). For visual changes, verify by rendering headless golden screenshots rather than guessing (throwaway golden test → `flutter test <file> --update-goldens` → open the PNG).

---

# Backend (Elixir umbrella) structure — where code goes

The backend is an Elixir **umbrella** (`apps/`). Each app is a bounded context;
several are still empty stubs reserved for a context documented under `docs/0X_*.md`.
**Put new backend code in the app that owns that concern — do NOT default to
dumping everything in `apps/stellar` + `apps/stellar_web`.**

```
apps/
  stellar/        # CORE DOMAIN: all Ash resources + domains (Accounts, Orgs,
                  #   Courses, Rbac, Payments…), Stellar.Repo, ALL migrations +
                  #   resource_snapshots, the release seeder (Stellar.Release).
  stellar_web/    # THE (only) Phoenix endpoint: router, controllers, plugs,
                  #   LiveViews, JSON API. ALL HTTP/web code lives here.
  stellar_ms/     # MEDIA STREAMING (two Cloudflare products, one leaf app):
                  #   VOD = ingest/transcode/HLS/CDN via Cloudflare Stream — facade
                  #   `StellarMs`, provider `StellarMs.CloudflareStream`; LIVE = WebRTC
                  #   SFU + TURN via Cloudflare Realtime — facade `StellarMs.Realtime`,
                  #   provider `StellarMs.CloudflareRealtime`.
  stellar_ai/     # AI (docs/05) — stub                stellar_rag/  # RAG (docs/09) — stub
  stellar_rt/     # notifications (docs/06) — stub (live video realtime → stellar_ms)
  stellar_quiz/   # quizzes/assessments (docs/07) — stub
  stellar_lrn/    stellar_job/   # learning / job-placement contexts — stubs
  stellar_fe/     # Flutter frontend (see "Flutter frontend structure" above)
```

Doc↔app map: `docs/03_course_management` → `stellar` (Stellar.Courses),
`docs/04_media_streaming` → **`stellar_ms`**, `docs/06/07/09` → `stellar_rt` /
`stellar_quiz` / `stellar_rag`.

## Rules when placing backend code

- **Media streaming / transcode / HLS / streaming-provider code → `apps/stellar_ms`.**
  Callers go through the `StellarMs` facade (`StellarMs.create_direct_upload/1`,
  `get_video/1`, `upload_file/2`, `normalize/1`, `verify_webhook/2`, `hls_url_for/1`),
  **never the provider module directly** — the facade is the provider-agnostic seam.
- **Live video / WebRTC signaling-provider code (SFU + TURN) → `apps/stellar_ms` too**,
  behind its own facade `StellarMs.Realtime` (provider `StellarMs.CloudflareRealtime`) —
  kept separate from `StellarMs` so the two `configured?/0` don't collide. The Phoenix
  signaling channel itself (`StellarWeb.LiveRoomChannel`, `live_room:*`) stays in
  `stellar_web` and proxies every SFU call through `StellarMs.Realtime`.
- **Domain resources stay in `apps/stellar` even if they *use* streaming.** A
  `Lecture` is a `Stellar.Courses` entity that *references* a video (it holds
  `cf_uid`/`hls_url` and calls `StellarMs`), so it lives with `Course`/
  `VideoCheckpoint`/`Transcript` in `stellar`, **not** in `stellar_ms`. The
  `lectures` table + its migration belong to `Stellar.Repo` (in `stellar`).
- **Dependency direction is `stellar_web → stellar → stellar_ms`.** Keep
  `stellar_ms` a **leaf** (no `in_umbrella` deps). Do NOT make `stellar_ms`
  depend on `stellar`: `Stellar.Repo` + `Course has_many :lectures` + the seeder
  would form an **umbrella dependency cycle** (Mix rejects it, and it breaks
  `compile --warnings-as-errors`). This is exactly why domain resources can't be
  moved into `stellar_ms`.
- **A feature app configures under its OWN otp_app key**, not `:stellar`:
  `config :stellar_ms, StellarMs.CloudflareStream, …` in `config/runtime.exs`.
  Read it with `Application.get_env(:stellar_ms, __MODULE__, [])`.
- **Wire a stub app before using it:** add real code under `apps/<app>/lib/`, add
  its runtime deps to `apps/<app>/mix.exs`, and add `{:<app>, in_umbrella: true}`
  to each app that calls into it.
- **Verify** (from repo root): `mix compile --warnings-as-errors` and
  `mix format --check-formatted` must be clean — CI's `precommit` alias runs both,
  then `mix test`. (On Windows see the toolchain memory: MSVC vcvars for NIFs,
  Postgres on 5438, the `mixdo.cmd` pattern.)