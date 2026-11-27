import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../shared/app_ui.dart';
import '../applications/applications_view.dart';
import '../shared/onboard_role.dart';
import '../landing/landing_page_ascent.dart' show JosjobLandingPage;
import '../explore/explore_page.dart'
    show ExploreCoursesView, showCatalogCourse;
import 'overview/learning_overview_view.dart';
import 'overview/jobs_overview_view.dart';
import 'screens/live_coaching_view.dart';
import 'screens/certificates_view.dart';
import 'screens/curriculum_vitae_view.dart';
import '../services/learning_overview_api.dart' show LearningCourse;
import '../services/session.dart';
import '../services/study_api.dart';
import '../jobs/jobs_page.dart' show JobsView;
import '../services/auth_api.dart' show AccountType;
import '../services/courses_api.dart'
    show CoursesApi, CourseSummary, EnrolledCourse, CourseApiException;

// =========================================================================
// JosJob — Role-adaptive Dashboard
//
// Reached after onboarding completes (and from main.dart). Renders a
// responsive shell — desktop sidebar + top bar, mobile top bar + bottom nav —
// with a role-adaptive Overview screen. INDIVIDUAL roles (worker / graduate)
// see a learner dashboard; ORG roles (employer / coordinator) see a manager
// dashboard. Other destinations retain their existing behavior.
//
// Design system is inherited from the landing / auth / onboarding modules:
// AppColors blue palette, Poppins, pill buttons, rounded cards. Data is
// fetched for the Learn overview, course catalog, enrollments and vacancies.
// Some other destinations still contain sample content.
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
part 'widgets/status_chip.dart';
part 'widgets/empty_state.dart';
part 'widgets/onboarding_progress_card.dart';
part 'widgets/progress_bar.dart';
part 'widgets/progress_ring.dart';
part 'widgets/mini_bar_chart.dart';
part 'widgets/stat_card.dart';
part 'widgets/stat_grid.dart';
part 'widgets/learner_row.dart';
part 'widgets/learner_table.dart';
part 'widgets/offering_card.dart';
part 'widgets/completion_overview_card.dart';
part 'widgets/invite_card.dart';
part 'widgets/activity_feed_card.dart';
part 'widgets/info_note.dart';

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
part 'screens/live_coaching_screen.dart';
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
  final String initialView, initialTab, applicationScope, applicationStatus;
  const DashboardPage({
    super.key,
    this.role,
    this.firstName,
    this.initialView = 'learn',
    this.initialTab = 'overview',
    this.applicationScope = 'mine',
    this.applicationStatus = '',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return _DashboardShell(
      role: widget.role,
      firstName: widget.firstName,
      initialView: widget.initialView,
      initialTab: widget.initialTab,
      applicationScope: widget.applicationScope,
      applicationStatus: widget.applicationStatus,
    );
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

/// Open the Jobs board (route registered in main.dart).
void _browseJobs(BuildContext c) => Navigator.of(c).pushNamed('/jobs');

/// Open the VOD upload flow — saves a video as a standalone Document, not a
/// lecture (route registered in main.dart). Surfaced from the org overview.
void _uploadVod(BuildContext c) => Navigator.of(c).pushNamed('/vod/document');

/// Open the Documents hub — browse documents you can access and manage who
/// each of your documents is shared with (route registered in main.dart).
void _documents(BuildContext c) => Navigator.of(c).pushNamed('/documents');

Future<void> _openLearningCourse(BuildContext context, LearningCourse course) =>
    showCatalogCourse(
      context,
      CourseSummary(
        id: course.id,
        title: course.title,
        description: course.description,
        industries: const [],
        classCount: 0,
        currency: course.currency,
        sectionName: course.section,
        priceCents: course.priceCents,
      ),
    );

/// Log out — clear the stored session, then navigate home clearing the stack.
void _logout(BuildContext c) {
  Session.instance.signOut();
  Navigator.of(c).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
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

/// Initials from a display name, e.g. "Ana Rivera" -> "AR".
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
