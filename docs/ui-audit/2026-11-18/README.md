# Web UI consistency audit — 18 November 2026

The main problem is fragmented Flutter styling: the app shares a palette, but
does not enforce a shared typography or component theme. Independently styled
screens are now visible alongside one another. There are also navigation/state
bugs that make the product feel inconsistent even when the styling matches.

This records the original audit and its fix backlog. The subsequent implementation
and verification are tracked in [the fix report](FIXES.md); the screenshots below
remain baseline evidence.

## Scope and evidence

- Baseline: `50c2c89a3834d6be66ee51a30b28ac74d42c9e0b`, branch
  `feat/public-jobs-hiring-chat`; running Docker app at `http://localhost:8081`.
- Inspected guest, demo candidate and demo employer screens at **1440×1000**,
  **390×844**, and a **768×1024** course-catalog sample.
- Visited landing, login/register, public jobs/detail, Learn/Jobs overviews,
  course catalog, My Courses, coaching/workspace, certificates/dialog, CV/editor,
  applications/detail, hiring/filtering, stage/withdraw dialogs, chat and Documents.
- Compared browser screenshots and accessibility snapshots with the current Dart
  source. Selected screenshots are saved in [`screenshots/`](screenshots/).
- Edit and stage dialogs were cancelled. No vacancy, application, profile,
  certificate or chat record was edited. Existing business data was preserved.
- Teacher/admin/pending-account screens received source review only. Actual
  onboarding steps, payment, live video, VOD playback, all validation/error
  permutations and other browsers were not fully inspected. The Phoenix admin
  UI on port 4000 is a separate surface; this audit focuses on Flutter web.
- **B** below means browser-confirmed; **S** means source-confirmed. Some findings
  combine both. Do not interpret an untested state as a confirmed runtime failure.

P1 means fix before the next polish/release pass because it breaks continuity,
misleads users, damages readability or affects a shared foundation. P2 means
standardize in the subsequent component pass. These priorities are audit judgments.

## Priority index

| ID | Priority | Finding | Evidence |
| --- | --- | --- | --- |
| UI-01 | P1 | No global typography/component theme; Poppins, General Sans and default Material text mix | B + S |
| UI-02 | P1 | Mascot, sparkle and legacy branding coexist | B + S |
| UI-03 | P2 | Page titles, content widths and gutters follow different rules | B + S |
| UI-04 | P2 | Buttons have independently defined shapes, heights and typography | B + S |
| UI-05 | P1 | Vacancy editor fields visibly differ from CV/certificate/coaching forms | B + S |
| UI-06 | P2 | Dialog surfaces and action semantics are inconsistent | B + S |
| UI-07 | P1 | Signing in to apply loses the selected job | B + S |
| UI-08 | P1 | Reload/deep-link state does not preserve the dashboard destination | B + S |
| UI-09 | P1 | Crossing the desktop/mobile breakpoint resets child screen state | B + S |
| UI-10 | P1 | Course tags wrap mid-word and actions escape fixed-height cards | B + S |
| UI-11 | P1 | Persistent toolbar actions imply working features and unread notifications | B + S |
| UI-12 | P2 | Product claims and link outcomes disagree across screens | B + S |
| UI-13 | P2 | Status colors are not consistently semantic | B + S |
| UI-14 | P2 | Similar view/filter controls have different appearances and selected states | B + S |
| UI-15 | P2 | The same records use different card/avatar/metadata conventions | B + S |
| UI-16 | P2 | Date, time, timezone and currency presentation is fragmented | B + S |
| UI-17 | P2 | Mobile summary/filter density delays the primary content | B + S |
| UI-18 | P2 | Empty/error/retry patterns vary between modules | B for empty; S for errors |
| UI-19 | P1 | Accessibility names are duplicated and some interactive regions nest | B + S |
| UI-20 | P2 | Course bookmarks promise saving but only retain widget-local state | S |

## Findings and proposed fixes

### UI-01 — Global typography and component defaults

`main.dart` sets a seeded color scheme, background and Material 3, but no global
text, button, input, chip, dialog or app-bar theme. Most headings use explicit
Poppins; landing buttons specify General Sans; unstyled labels and app bars use
Material defaults. The vacancy editor and application detail header make the
difference especially visible.

**Owners:** [main.dart](../../../apps/josjob_fe/lib/main.dart#L43),
[theme tokens](../../../apps/josjob_fe/lib/theme/app_theme.dart#L14),
[landing button](../../../apps/josjob_fe/lib/landing/widgets/pill_button.dart#L87).
**Compare:** [login](screenshots/03-login-desktop.png),
[job editor](screenshots/27-job-editor-desktop.png).
**Fix/acceptance:** establish named text roles and global component themes using
the documented Poppins/blue baseline. Explicit exceptions should be intentional;
default labels, dropdowns and modal titles must no longer fall back unexpectedly.

### UI-02 — Branding changes when navigating

Landing uses `josjob-logo.svg` (the mascot); auth, the dashboard and public jobs
use `Icons.auto_awesome`. The same brand name also appears at different weights
and sizes without a shared lockup. The live landing footer literally starts with
`? 2026` and still mentions Stellar. The pending-organization message says Atveti
(source-only; not visited as an organization user).

**Owners:** [landing](../../../apps/josjob_fe/lib/landing/shell/josjob_landing_page.dart#L242),
[footer](../../../apps/josjob_fe/lib/landing/shell/josjob_landing_page.dart#L487),
[auth logo](../../../apps/josjob_fe/lib/auth/shell/brand_logo.dart#L16),
[dashboard logo](../../../apps/josjob_fe/lib/dashboard/shell/sidebar.dart#L73),
[pending message](../../../apps/josjob_fe/lib/auth/org_pending_page.dart#L77).
**Compare:** [landing](screenshots/01-landing-desktop.png),
[login](screenshots/03-login-desktop.png), [footer](screenshots/47-landing-footer.png).
**Fix/acceptance:** use one brand component with intentional light/dark/compact
variants and approved attribution wording. Use a valid copyright character.

### UI-03 — Titles, widths and gutters have no common hierarchy

My Courses uses the 18px section-header component as its page title, while CV
and coaching use 26px headings and catalogs use much larger hero headings.
Standalone details/editors introduce different app bars and 760/900/1100px
content constraints. Documents uses a 16px Poppins app-bar title; other pages
use either a 20px branded title or an unstyled Material title. Dashboard hosting
can add another layer of padding around a standalone-designed catalog.

**Owners:** [dashboard shell](../../../apps/josjob_fe/lib/dashboard/shell/dashboard_shell.dart#L153),
[section header](../../../apps/josjob_fe/lib/dashboard/widgets/section_header.dart#L22),
[My Courses](../../../apps/josjob_fe/lib/dashboard/screens/my_courses_screen.dart#L68),
[Documents](../../../apps/josjob_fe/lib/documents/documents_page.dart#L107),
[coaching wrapper](../../../apps/josjob_fe/lib/dashboard/screens/live_coaching_view.dart#L21).
**Fix/acceptance:** define page-header, section-header and marketing-hero roles,
plus bounded page/form widths and gutter tokens. Embedded and standalone views
should share these rules. A focused chat/player may keep its own purposeful shell.

### UI-04 — Buttons follow several component systems

The landing `_PillButton` is actually an 8px rounded rectangle with General Sans;
dashboard and explore implement separate stadium buttons; auth uses large
Poppins pills; newer views mix default Filled/Outlined/Text buttons. For example,
the large My Courses empty-state CTA, small certificate CTA and outlined
application actions have unrelated size and emphasis rules.

**Owners:** [landing button](../../../apps/josjob_fe/lib/landing/widgets/pill_button.dart#L5),
[dashboard button](../../../apps/josjob_fe/lib/dashboard/widgets/pill_button.dart#L9),
[explore button](../../../apps/josjob_fe/lib/explore/widgets/pill_button.dart#L8).
**Fix/acceptance:** shared primary/secondary/tertiary/destructive variants and
named size tiers, consistent focus/loading states and icon spacing. Different
contexts may use different tiers; they should not invent their own button system.

### UI-05 — The vacancy editor looks like a different application

The vacancy form uses default outlined TextFormFields, floating labels, visible
character counters, default text and small corner radii. CV, certificate and
coaching forms use above-field labels, Poppins, white fields and 14px corners.
The vacancy description's empty label sits in the middle of a tall textarea.

**Owners:** [vacancy fields](../../../apps/josjob_fe/lib/jobs/screens/job_editor.dart#L236),
[shared field](../../../apps/josjob_fe/lib/shared/app_form_field.dart#L12).
**Compare:** [vacancy editor](screenshots/28-job-editor-mobile.png),
[CV editor](screenshots/25-cv-edit-mobile.png),
[certificate editor](screenshots/34-certificate-dialog.png).
**Fix/acceptance:** migrate job inputs/selects to the shared field treatment;
standardize required/optional labels, helper/error text and counter behavior.
Multiline labels should remain at the top. Retain existing validation and limits.

### UI-06 — Dialog theme and destructive actions differ

CV/certificate dialogs use `appFormTheme` with white surfaces and Poppins.
Stage/withdraw dialogs use an unthemed AlertDialog, producing a tinted surface
and a default-font title beside a Poppins form field. Withdrawal uses the same
blue generic **Confirm** action as advancing a stage.

**Owners:** [form theme](../../../apps/josjob_fe/lib/shared/app_form_field.dart#L112),
[stage dialog](../../../apps/josjob_fe/lib/applications/applications_view.dart#L444).
**Compare:** [CV](screenshots/25-cv-edit-mobile.png),
[withdraw](screenshots/37-withdraw-dialog.png),
[advance](screenshots/44-hiring-stage-dialog.png).
**Fix/acceptance:** one modal surface/title/action layout; verb-specific actions
such as **Withdraw application** and **Move to Reviewing**, with destructive
emphasis where appropriate. Existing shared date/time-picker theming can be kept.

### UI-07 — Sign in to apply loses the job

**Reproduce:** signed out → open Junior Backend Developer → Sign in to apply →
log in → Go to dashboard. The result is Learn Overview rather than the selected
role/application form. This also disagrees with the intended frontend PRD flow.

**Owners:** [apply action](../../../apps/josjob_fe/lib/jobs/screens/job_detail.dart#L24),
[login destination](../../../apps/josjob_fe/lib/auth/data/helpers.dart#L36).
**Evidence:** [result after job login](screenshots/41-after-job-login.png).
**Fix/acceptance:** retain a validated internal return destination/job ID through
login, registration and required onboarding; return to the original job with the
intended apply action. Cancelling auth should keep the original browsing context.

### UI-08 — Dashboard and detail URLs do not preserve the destination

**Reproduce:** dashboard → Jobs → Curriculum Vitae → reload. After the bootstrap
finishes, the app displays Learn Overview. Dashboard selection is held in `_view`
and `_index`; many details use unnamed MaterialPageRoutes. The inspected job,
application and form screens do not expose shareable record-specific URLs.

**Owners:** [shell state](../../../apps/josjob_fe/lib/dashboard/shell/dashboard_shell.dart#L18),
[route table](../../../apps/josjob_fe/lib/main.dart#L103),
[detail navigation](../../../apps/josjob_fe/lib/jobs/jobs_page.dart#L99).
**Compare:** [before reload](screenshots/48-before-dashboard-reload.png),
[after reload](screenshots/35-dashboard-after-cv-reload.png).
**Fix/acceptance:** URL-backed product/destination/record state. Reload, browser
Back/Forward and copying a job/application URL must resolve to the same authorized
screen. Keep private routes gated and public active-job details public.

### UI-09 — Desktop/mobile transitions reset the active workspace

**Reproduce:** employer → Jobs → Applications → Hiring → Reviewing; resize from
1440px to 390px. The content becomes **My applications / All stages**, with an
empty list, despite the same employer session. The shell replaces the desktop
and mobile widget hierarchies; child `ApplicationsView` initializes its scope
again from the default `hiring: false` value.

**Owners:** [responsive shell switch](../../../apps/josjob_fe/lib/dashboard/shell/dashboard_shell.dart#L148),
[child scope](../../../apps/josjob_fe/lib/applications/applications_view.dart#L92).
**Compare:** [before](screenshots/42-hiring-before-resize.png),
[after](screenshots/43-hiring-after-resize.png).
**Fix/acceptance:** preserve page state above responsive presentation or maintain
a stable stateful subtree. Verify scope, stage/search filters, pagination,
scroll and unsaved input while crossing the breakpoint in both directions.

### UI-10 — Course cards cannot reliably fit their content

At 1440px with the dashboard sidebar, **Hospitality** in the multi-category Front
Office card wraps as `Hospitalit` / `y`, and its **View course** action extends
below the card boundary. The grid chooses three columns from viewport width,
despite the narrower embedded content width; cards have a fixed 356px height.
The tag has no max-line/overflow rule.

**Owners:** [grid](../../../apps/josjob_fe/lib/explore/widgets/course_grid.dart#L35),
[fixed card](../../../apps/josjob_fe/lib/explore/widgets/course_card.dart#L21),
[tag](../../../apps/josjob_fe/lib/explore/widgets/tag_pill.dart#L15).
**Evidence:** [course layout](screenshots/45-course-card-layout.png).
**Fix/acceptance:** select columns from available constraints and a minimum card
width; let card height accommodate supported content or budget each section.
Keep tags on one line or use a controlled overflow strategy. Test long titles,
multiple categories, price labels and larger text scaling; actions must stay inside.

### UI-11 — Toolbar actions and unread indicators imply live functionality

The dashboard always exposes **Ask AI** and a notification indicator labelled
**3 unread**. Both invoke the same **Demo — no backend yet.** snackbar. This
conflicts with the otherwise real data in vacancies, applications and learning.

**Owners:** [toolbar](../../../apps/josjob_fe/lib/dashboard/shell/top_bar.dart#L63),
[notification label](../../../apps/josjob_fe/lib/dashboard/shell/top_bar.dart#L134),
[demo feedback](../../../apps/josjob_fe/lib/dashboard/dashboard_page.dart#L126).
**Fix/acceptance:** show real capability/unread state or clearly mark/remove
unavailable actions. Do not display invented unread counts as user activity.

### UI-12 — Copy and link behavior disagree about feature availability

The landing labels matching as planned, while login promises **AI job matching
to live vacancies** and says job matches are waiting. **Forgot password?** and
the registration Terms/Privacy links lead to coming-soon feedback rather than
their advertised destinations. Coaching also exposes configuration-oriented copy
about video being enabled when live video is configured.

**Owners:** [login copy/actions](../../../apps/josjob_fe/lib/auth/screens/login_page.dart#L110),
[registration links](../../../apps/josjob_fe/lib/auth/screens/register_page.dart#L416),
[coaching content](../../../apps/josjob_fe/lib/dashboard/screens/live_coaching_view.dart).
**Evidence:** [login](screenshots/03-login-desktop.png),
[coaching](screenshots/13-coaching-desktop.png).
**Fix/acceptance:** a single capability/copy inventory. Label planned features
consistently, describe temporary unavailability in user language, and make links
open their promised page or present an explicit unavailable state before selection.

### UI-13 — Status colors do not share semantic rules

The generic job badge is always green, so an employer's expired/draft status
receives the same treatment as a synthetic-data badge. Application stages use
blue for both ongoing stages and Hired, with grey for rejected/withdrawn. Other
modules define their own status pills. Text labels remain present, which is good.

**Owners:** [job badge](../../../apps/josjob_fe/lib/jobs/jobs_page.dart#L185),
[badge call site](../../../apps/josjob_fe/lib/jobs/widgets/job_card.dart#L91),
[application badge](../../../apps/josjob_fe/lib/applications/applications_view.dart#L40).
**Fix/acceptance:** separate data-provenance badges from workflow statuses; define
neutral/info/success/warning/closed/danger treatments with text and optional icons.

### UI-14 — View toggles and filters use unrelated interaction treatments

Learn/Jobs uses a strong blue segmented pill; Mine/Hiring uses default lavender
checkbox-like ChoiceChips; coaching uses TextButtons; the course catalog uses
colored category tiles and a sort menu, while vacancies use outlined dropdowns.
For equivalent selected-state tasks, shape, density and emphasis are unpredictable.

**Owners:** [view switcher](../../../apps/josjob_fe/lib/dashboard/shell/view_switcher.dart),
[application scopes/filters](../../../apps/josjob_fe/lib/applications/applications_view.dart#L198),
[coaching switches](../../../apps/josjob_fe/lib/dashboard/screens/live_coaching_view.dart#L349).
**Fix/acceptance:** distinguish navigation tabs, single-select filters, multi-select
filters and category cards, then give each a shared selected/hover/focus treatment.
Do not make all controls identical when their semantics differ.

### UI-15 — Matching records have different cards and avatars

The same vacancy uses a single-letter flat avatar in Jobs Overview and a
two-character gradient avatar in the board. For the demo company the latter
initials include `[` from `[Demo]`. Employment labels are title-cased in Overview
but raw `full-time`/`remote` on the board; synthetic labels also differ. Course
previews have a similarly separate overview/catalog treatment.

**Owners:** [overview card](../../../apps/josjob_fe/lib/dashboard/overview/jobs_overview_view.dart#L343),
[board card](../../../apps/josjob_fe/lib/jobs/widgets/job_card.dart),
[initials](../../../apps/josjob_fe/lib/jobs/jobs_page.dart#L155).
**Fix/acceptance:** shared compact/full record-card variants, shared company
avatar generation and metadata formatters. Punctuation-only initials must not
appear. Keep synthetic records explicitly distinguishable without changing data.

### UI-16 — Date, timezone and currency formatting differ

Job previews show `Published 2026-11-17`; applications show `17/11/2026 · 22:59`;
chat uses another slash-date layout; coaching uses year-first dates and a range.
Coaching identifies local timezone behavior, while interview/chat dates do not
consistently label it. Course prices use dollar symbols while jobs use explicit
IDR codes. Different underlying currencies may be legitimate; the presentation
should identify them clearly rather than converting or guessing.

**Owners:** [job previews](../../../apps/josjob_fe/lib/dashboard/overview/jobs_overview_view.dart#L392),
[application dates](../../../apps/josjob_fe/lib/applications/applications_view.dart#L22),
[chat time](../../../apps/josjob_fe/lib/chat/chat_page.dart#L218),
[coaching time](../../../apps/josjob_fe/lib/dashboard/screens/live_coaching_view.dart#L14).
**Fix/acceptance:** shared locale-aware display formatters with explicit currency
and consistent timezone labeling for scheduled events. Preserve date-only/partial
date precision and the backend's currency values.

### UI-17 — Mobile filter/summary density hides the main task

Applications renders a title, Refresh, a row/wrap of per-stage counts, and another
wrap of stage filters before the first application. Hiring adds a second scope
selector. In the 390px capture the first card starts around 530px down; public
jobs also spends most of the first viewport on hero and filter controls.

**Evidence:** [mobile applications](screenshots/36-applications-mobile.png),
[mobile hiring](screenshots/43-hiring-after-resize.png).
**Owners:** [counts and filters](../../../apps/josjob_fe/lib/applications/applications_view.dart#L214),
[mobile jobs layout](../../../apps/josjob_fe/lib/jobs/screens/job_board.dart).
**Fix/acceptance:** compact summaries and one clearly selected stage control;
collapse advanced filters on small screens and retain a visible result count.
Compare the first useful content/action across mobile destinations.

### UI-18 — Empty, error and retry states are independently designed

My Courses has a large centered card and full-width tinted CTA; coaching has
small text-only cards; certificates uses a centered icon; Documents has a plain
message and toolbar refresh. Error recovery follows these separate wrappers,
including inline Retry in some modules but toolbar-only refresh in Documents.
The error-state comparison is source review, not an induced network-failure test.

**Owners:** [My Courses](../../../apps/josjob_fe/lib/dashboard/screens/my_courses_screen.dart#L95),
[certificates](../../../apps/josjob_fe/lib/dashboard/screens/certificates_view.dart#L217),
[Documents](../../../apps/josjob_fe/lib/documents/documents_page.dart#L131),
[jobs message](../../../apps/josjob_fe/lib/jobs/screens/job_board.dart#L629).
**Fix/acceptance:** shared state components with full-page and inline variants,
consistent icon/heading/body/action order, accessible announcements, and a clear
retry/sign-in/next-step action suited to the failure. Preserve honest empty data.

### UI-19 — Accessibility labels repeat and interactive regions nest

Browser accessibility snapshots contain **Ask AI Ask AI**, **Overview Overview**,
**Learn Learn**, **View course View course**, and a Documents button nested in a
Documents button. Course cards are marked as buttons around inner Save/View
buttons. This makes control names and focus expectations less consistent.

**Owners:** [sidebar item](../../../apps/josjob_fe/lib/dashboard/shell/sidebar_nav_item.dart#L20),
[dashboard button](../../../apps/josjob_fe/lib/dashboard/widgets/pill_button.dart#L64),
[toolbar](../../../apps/josjob_fe/lib/dashboard/shell/top_bar.dart#L46),
[course card](../../../apps/josjob_fe/lib/explore/widgets/course_card.dart#L24).
**Fix/acceptance:** one intended accessible name per control; avoid redundant
parent labels or use appropriate exclusion/merging. Validate keyboard order,
button roles and independently reachable secondary card actions. Do not just
silence tests by matching duplicated labels.

### UI-20 — Course saving has a different persistence contract

The course catalog toggles an in-memory `_saved` set and displays **Saved to your
list**, with no durable save operation in that handler. Recreating the widget
initializes an empty set. Unlike applications and CV details, this apparent save
does not have an account-backed persistence contract. This finding is
source-confirmed; persistence should receive a dedicated browser regression.

**Owner:** [local saved state/handler](../../../apps/josjob_fe/lib/explore/shell/explore_shell.dart#L38)
and [toggle](../../../apps/josjob_fe/lib/explore/shell/explore_shell.dart#L147).
**Fix/acceptance:** either implement and verify the intended persistence or clearly
label the limited behavior/hide the control until supported. Test navigation and
reload; do not imply durable saving when only a local widget state changed.

## Fix sequence

1. **Continuity and layout bugs:** UI-07, UI-08, UI-09, UI-10. Preserve the user's
   task before changing visual details. Add focused regression cases for these
   newly discovered behaviors; earlier backend hiring tests do not cover them.
2. **Shared foundation:** UI-01, UI-02, UI-04, UI-05, UI-06. Establish the global
   theme, brand lockup, field/select and dialog/button variants once. Reuse the
   existing palette and form helpers; an additional UI framework is not required.
3. **Migrate the main journeys:** page headers/gutters, record cards, filters,
   badges, empty/error states and mobile density. Retain useful compact/full
   variants and the intentional difference between marketing and workspaces.
4. **Truthfulness and accessibility:** remove invented unread states, align
   capability copy/link outcomes, clarify bookmarks, centralize formats and
   validate semantics/keyboard interaction throughout the migrated components.

Suggested common components: BrandLogo, PageHeader, Button with variants/sizes,
Field/Select/Search, Card, StatusBadge, Tabs/FilterControl, EmptyState/ErrorState
and dialog helpers. Names are proposals, not a request to introduce all of them
before a concrete screen needs them.

## What should be preserved

- The blue/navy palette and most Poppins content already provide a useful base.
- Public and dashboard vacancy browsing already share `JobsView`.
- Hiring and coaching chat use the same `ChatPage`/`ChatPanel`; keep that shared
  implementation. Hiring chat was visually reviewed; coaching chat was checked
  through the shared source rather than a new booking.
- CV, certificate and coaching fields already reuse shared form helpers.
- Real API-backed data and explicit synthetic labels should stay truthful.
- Separate shells for focused chat/live/media tasks can be intentional. Their
  brand, typography, controls and return paths should still be consistent.

## Acceptance pass when implementing

- Revisit the captured guest/candidate/employer journeys at 390, 768, 1024 and
  1440px, including just above/below the desktop breakpoint and larger text sizes.
- Verify login/registration continuation, record deep links, reload, Back/Forward,
  scope/filter persistence and keyboard focus before declaring the polish complete.
- Exercise loading, empty, validation, request failure, disabled, in-progress and
  success/terminal states with the same components.
- Check both chat entry points, real and synthetic records, long labels/company
  names, multiple categories and differing currencies.
- Add meaningful widget/browser regressions for the functional findings and
  visual comparisons for shared components, then run the repository's required
  checks. This audit itself did not modify application code or run a new full suite.
