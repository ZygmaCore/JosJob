import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../shared/onboard_role.dart';
import '../landing/landing_page_ascent.dart' show StellarLandingPage;
import '../quiz/quiz_page.dart' show QuizPage;
import '../vod/vod_page.dart' show VodPlayerPage;
import '../explore/explore_page.dart' show ExploreCoursesView;
import '../live/live_call_page.dart' show LiveCallPage;
import '../live/data/live_models.dart'
    show LiveRoomMode, ParticipantRole, classRoomId;
import '../services/session.dart';
import '../jobs/jobs_page.dart' show JobsView;
import '../services/auth_api.dart' show AccountType, AuthException;
import '../services/classes_api.dart';
import '../services/courses_api.dart'
    show CoursesApi, EnrolledCourse, CourseApiException;

// =========================================================================
// ATVETI STELLAR — Role-adaptive Dashboard (UI only, no backend)
//
// Reached after onboarding completes (and from main.dart). Renders a
// responsive shell — desktop sidebar + top bar, mobile top bar + bottom nav —
// with a role-adaptive Overview screen. INDIVIDUAL roles (worker / graduate)
// see a learner dashboard; ORG roles (employer / coordinator) see a manager
// dashboard. Every other nav destination shows a polished placeholder.
//
// Design system is inherited from the landing / auth / onboarding modules:
// AppColors blue palette, Poppins, pill buttons, rounded cards. All data is
// hard-coded sample content — nothing is persisted or fetched.
//
// The whole module is assembled from `part` files, one component per file,
// grouped under shell/ overview/ widgets/ data/. This library file owns every
// import and public symbol; part files carry no imports of their own.
// =========================================================================

// ---- data ---------------------------------------------------------------
part 'data/models.dart';
part 'data/demo_data.dart';
part 'data/jobs_demo.dart';

// ---- widgets ------------------------------------------------------------
part 'widgets/pill_button.dart';
part 'widgets/avatar.dart';
part 'widgets/dash_card.dart';
part 'widgets/section_header.dart';
part 'widgets/greeting_header.dart';
part 'widgets/status_chip.dart';
part 'widgets/empty_state.dart';
part 'widgets/onboarding_progress_card.dart';
part 'widgets/progress_bar.dart';
part 'widgets/progress_ring.dart';
part 'widgets/mini_bar_chart.dart';
part 'widgets/stat_card.dart';
part 'widgets/stat_grid.dart';
part 'widgets/course_progress_card.dart';
part 'widgets/recommended_course_card.dart';
part 'widgets/weekly_activity_card.dart';
part 'widgets/coaching_tile.dart';
part 'widgets/up_next_card.dart';
part 'widgets/ai_assistant_card.dart';
part 'widgets/certificate_row.dart';
part 'widgets/certificates_card.dart';
part 'widgets/learner_row.dart';
part 'widgets/learner_table.dart';
part 'widgets/offering_card.dart';
part 'widgets/completion_overview_card.dart';
part 'widgets/invite_card.dart';
part 'widgets/activity_feed_card.dart';
part 'widgets/job_match_card.dart';
part 'widgets/applications_card.dart';
part 'widgets/jobs_aside_cards.dart';
part 'widgets/info_note.dart';
part 'widgets/target_cert_card.dart';
part 'widgets/coach_card.dart';
part 'widgets/coach_search_field.dart';
part 'widgets/coach_focus_chips.dart';
part 'widgets/coach_sort_control.dart';
part 'widgets/enrolled_classes_card.dart';

// ---- shell --------------------------------------------------------------
part 'shell/sidebar_nav_item.dart';
part 'shell/sidebar.dart';
part 'shell/top_bar.dart';
part 'shell/bottom_nav.dart';
part 'shell/mobile_drawer.dart';
part 'shell/placeholder_panel.dart';
part 'shell/view_switcher.dart';
part 'shell/dashboard_shell.dart';

// ---- overview -----------------------------------------------------------
part 'overview/overview_individual.dart';
part 'overview/overview_org.dart';
part 'overview/overview_jobs.dart';

// ---- screens ------------------------------------------------------------
part 'screens/certificates_screen.dart';
part 'screens/live_coaching_screen.dart';
part 'screens/coach_browser.dart';
part 'screens/my_courses_screen.dart';
part 'screens/vacancies_screen.dart';
part 'screens/cv_screen.dart';
part 'screens/job_applications_screen.dart';
part 'screens/my_team_screen.dart';
part 'screens/training_screen.dart';
part 'screens/reports_screen.dart';

// =========================================================================
// Public entry point — imported by onboarding and main.dart.
// Keep this constructor signature stable.
// =========================================================================
class DashboardPage extends StatefulWidget {
  final OnboardRole? role;
  final String? firstName;
  const DashboardPage({super.key, this.role, this.firstName});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return _DashboardShell(role: widget.role, firstName: widget.firstName);
  }
}

// =========================================================================
// Shared helpers (library-private, visible to every part file)
// =========================================================================

/// Employer and coordinator manage others (ORG view); worker and graduate are
/// learners (INDIVIDUAL view). A null role defaults to the individual view.
bool isOrg(OnboardRole? r) =>
    r == OnboardRole.employer || r == OnboardRole.coordinator;

bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

/// Standard "no backend" feedback for demo-only buttons.
void _demoAction(BuildContext c) {
  ScaffoldMessenger.of(c)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
        content: Text(
          'Demo — no backend yet.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
}

/// Open the Explore Courses catalog (route registered in main.dart).
void _explore(BuildContext c) => Navigator.of(c).pushNamed('/explore');

/// Open the Quizzes & assessments hub (route registered in main.dart).
void _quiz(BuildContext c) => Navigator.of(c).pushNamed('/quiz');

/// Open the Jobs board (route registered in main.dart).
void _browseJobs(BuildContext c) => Navigator.of(c).pushNamed('/jobs');

/// Open the VOD upload flow — saves a video as a standalone Document, not a
/// lecture (route registered in main.dart). Surfaced from the org overview.
void _uploadVod(BuildContext c) => Navigator.of(c).pushNamed('/vod/document');

/// Open the Documents hub — browse documents you can access and manage who
/// each of your documents is shared with (route registered in main.dart).
void _documents(BuildContext c) => Navigator.of(c).pushNamed('/documents');

/// Resume a course by opening the lecture video (VOD player). The demo courses
/// don't map to specific backend lectures, so the player resolves the first
/// available lecture from the API itself.
void _resumeCourse(BuildContext c) {
  Navigator.of(c)
      .push(MaterialPageRoute(builder: (_) => const VodPlayerPage()));
}

/// Jump straight into a live classroom quiz session (the "Join" action on a
/// live-coaching tile). Opens the quiz hub already fast-forwarded to the live
/// screen, so backing out lands on the hub.
void _liveClass(BuildContext c) => Navigator.of(
  c,
).push(MaterialPageRoute(builder: (_) => const QuizPage(autoStartLive: true)));

/// Open a real-time WebRTC video session (Cloudflare Realtime SFU). Everyone
/// who opens the same [room] joins the same call. Pushed as a full page so it
/// inherits the dashboard's auth guard.
void _startLive(
  BuildContext c, {
  required LiveRoomMode mode,
  required ParticipantRole role,
  required String room,
}) {
  final name = Session.instance.user?.firstName;
  Navigator.of(c).push(
    MaterialPageRoute(
      builder: (_) => LiveCallPage(
        roomId: room,
        mode: mode,
        role: role,
        displayName: (name != null && name.isNotEmpty) ? name : null,
      ),
    ),
  );
}

/// Log out — clear the stored session, then navigate home clearing the stack.
void _logout(BuildContext c) {
  Session.instance.signOut();
  Navigator.of(c).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const StellarLandingPage()),
    (route) => false,
  );
}

/// Card shadow used across the module.
const _cardShadow = BoxShadow(
  color: Color(0x0D000000), // black @ 5%
  blurRadius: 24,
  offset: Offset(0, 10),
);

/// Tabular figures for numbers that sit in columns / rows.
TextStyle _tabular(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Deterministic thumbnail gradient keyed by a small seed.
LinearGradient _thumbGradient(int seed) {
  const pairs = <List<Color>>[
    [AppColors.brandBlue, AppColors.accent],
    [AppColors.navy, AppColors.brandBlue],
    [AppColors.heroBlue, Color(0xFF56B0F5)],
    [AppColors.orange, Color(0xFFF7B95C)],
  ];
  final p = pairs[seed % pairs.length];
  return LinearGradient(
    colors: p,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Initials from a display name, e.g. "Ana Rivera" -> "AR".
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
