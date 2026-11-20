# Landing page refresh using the daisyUI Codex skill

The official skill from `saadeghi/daisyui` is installed in
`C:/Users/LOQ/.codex/skills/daisyui`. The requested `npx skills add` command
stalled while cloning the repository. The same official skill directory was
then downloaded directly from Git tree
`10c87783e57b4f2f6ecdbab9a2f31dcda0de41dc`; all 73 files were checked against
their Git blob hashes. Codex can discover the installed skill on the next turn.

The product landing page is Flutter web. This refresh applies the skill's hero,
navbar, card, browser-mockup, steps, collapse and footer guidance as Flutter
widgets. It does not add a CSS library to the Flutter renderer or replace the
frontend architecture. The shared JosJob colors, mascot and Poppins typography
are retained.

## Changes

- A persistent navigation bar and mobile menu preserve access to login, public
  jobs, the journey section and FAQs while scrolling.
- A shorter hero leads with account creation and public job discovery.
- A labeled illustrative workspace preview shows the real five-stage hiring
  sequence. It does not claim sample vacancies or account progress are live data.
- Job, learning and coaching cards link to their existing destinations. Learning
  and coaching retain their normal authentication gates.
- Three journey steps describe implemented behavior. The AI roadmap is a
  separate, explicitly planned callout.
- Responsive FAQ cards support keyboard activation and expanded-state semantics.
- The closing signup section and footer contain working destinations.

## Verification

- Release web build completed; local Docker frontend image rebuilt and recreated.
- Targeted analyzer for the changed active landing files and app entry: no issues.
- Analyzing the entire legacy landing directory still reports ten unused
  declarations/parameters in older, unchanged sections. They predate this refresh
  and were not deleted or suppressed.
- `mix precommit` passed: 286 tests and 7 doctests, no failures. Existing Ash
  notification/test warnings remain.
- All six Chromium checks passed in `e2e/tests/landing.spec.ts`. They exercise public jobs,
  registration links at 320/768/1440px, the mobile drawer, FAQ keyboard operation,
  reduced motion, section anchors and the closing signup action.
- Captured ten screenshots at 320, 390, 768 and 1440px with zero browser
  `pageerror` events. Selected captures: [desktop hero](landing-after/hero-1440.png),
  [mobile hero](landing-after/hero-390.png),
  [feature cards](landing-after/features-desktop.png),
  [journey](landing-after/journey-desktop.png), and
  [mobile FAQ](landing-after/faq-mobile.png).

This pass changes landing presentation and navigation only. Existing manual job,
application, chat and profile records are preserved.

## Further landing enhancement

The next pass makes the hero more useful as well as more visual:

- New headline, search field, improved small-screen spacing and a layered product
  preview with a restrained dot pattern, using the existing brand palette.
- Hero search opens `/jobs?q=...`, including proper encoding of spaces and `&`.
  Empty searches open the full public list. Navigation releases the search focus.
  The route-information provider reports canonical encoded URLs through the web
  engine's supported location channel, avoiding its URI-channel unescaping of
  reserved query characters. Regression cases cover query preservation and
  browser-history replacement behavior.
- Jobs, Learning and Coaching choices switch the illustrative preview and its
  working destination button. Sample content remains explicitly labeled.
- `/welcome` is a public landing destination for both guests and signed-in users.
  Signed-in visitors get Dashboard/workspace actions and keep their session.
- Feature cards have separate semantic groups and accurate pointer cursors;
  learning and coaching use the shared orange/green semantic colors.
- FAQ accessibility focus is connected to its actual focus node, including
  browser keyboard focus and expanded-state announcements.

The original screenshots above remain evidence of the first refresh.

Second-pass verification:

- All **11 Chromium checks passed**, including full search keyword/URL
  preservation through reload, empty search, all three product choices at 320px
  and desktop, signed-in `/welcome` access, keyboard FAQs and reduced motion.
- All **6 routing widget/regression tests passed**; the targeted analyzer
  reported no issues in the changed landing, router and app-entry files.
- Release build completed and the Docker frontend was rebuilt/recreated.
- Final `mix precommit` passed again: **286 tests + 7 doctests, zero failures**.
  Docker frontend and database health checks are healthy; the backend is running.
- A separate read-only browser check confirmed dashboard Back/Forward and reload
  still preserve the hiring scope/stage after the URL-provider change.
- Reviewed 16 desktop/mobile captures. New selected screenshots:
  [desktop hero](landing-v2-after/hero-1440.png),
  [mobile hero](landing-v2-after/hero-390.png),
  [learning preview](landing-v2-after/preview-learning-1440.png),
  [mobile coaching preview](landing-v2-after/preview-coaching-320.png), and
  [feature cards](landing-v2-after/features-desktop.png).

Preview the current landing page at `http://localhost:8081/#/welcome`, including
while signed in. The `/` destination continues to open the appropriate workspace
for an existing session.

## Animated hero word

The headline now rotates **ambitions → dreams → ideas → goals → plans** at a
500ms cadence. Each handoff takes 260ms and combines a clipped vertical slide,
staggered fades, slight blur and a blue underline. The widest word reserves its
layout space so the rest of the page does not move as words change.

Rotation loops automatically, including while hovered, without a pause/resume
control, following the requested revision. It stops for reduced-motion
preferences, inactive app lifecycle states and covered
routes. Timer and animation resources are disposed with the widget. Screen
readers receive one stable heading instead of announcements every half second.

Validation: four focused widget tests passed for exact cadence, stable sizing,
automatic looping through a complete cycle while hovered, reduced motion and
route/disposal behavior. The targeted
analyzer is clean; the release build and Docker deployment completed. All 13
landing-page browser checks passed before the automatic-loop revision. The
headline browser checks were updated to check the absence of a pause control.
Desktop and 320px visual captures reported no browser errors.
Initial captures (before removing the pause control): [desktop](headline-animation/desktop.png),
[320px mobile](headline-animation/mobile.png), and
[another word in the rotation](headline-animation/rotating-word.png).
Current automatic-loop captures: [desktop](headline-animation/autoloop-1440.png)
and [320px mobile](headline-animation/autoloop-320.png), with no browser errors.

For this animation change, `mix precommit` was attempted twice but could not
start: Debian WSL returned `HCS_E_CONNECTION_TIMEOUT` while creating its VM.
This is an infrastructure failure; no new backend test result is claimed.
The earlier successful backend verification above remains historical evidence.
The automatic-loop revision also attempted `mix precommit`; WSL returned the
same VM startup timeout. Four revised widget tests, the targeted analyzer and
the release build passed, and the local Docker frontend was recreated.
All 13 browser checks passed on the revision, including signed-in welcome access.
The first run had one page-initialization timeout before the desktop tour test;
the complete rerun passed without changing application code.

Before pushing the UI branch, the full native `flutter test` run passed 111
tests. The existing `_tmp_register_flow_test.dart` failed to compile because its
authentication imports include browser-only Google identity JS interop. This
native-runner limitation is separate from the successful release web build and
13 Chromium landing checks. The failed test was left unchanged.
