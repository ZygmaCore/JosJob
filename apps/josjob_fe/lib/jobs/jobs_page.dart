import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../services/job_rankings_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/jobs_api.dart';
import '../services/session.dart';
import '../services/auth_api.dart' show AuthException;
import '../applications/applications_view.dart';
import '../shared/app_ui.dart';
import '../shared/app_formats.dart';
import '../shared/app_form_field.dart';
import '../services/ui_preferences.dart';

// =========================================================================
// JOSJOB - Public job browsing and authenticated employer listing management.
//
// The standalone browse-roles surface reached from the dashboard's Jobs view
// ("Browse all roles") and the landing "Jobs" nav, registered at /jobs. A
// Search, filters and pagination are served by JobsApi; details are refetched
// on open. The design system is shared with the rest of the app.
//
// One library assembled from `part` files; this file owns every import and the
// public entry widget. Part files carry no imports of their own.
// =========================================================================

part 'widgets/search_field.dart';
part 'widgets/job_card.dart';
part 'screens/job_board.dart';
part 'screens/cv_job_rankings.dart';
part 'screens/job_detail.dart';
part 'screens/job_editor.dart';

// =========================================================================
// Public entry point - registered as the /jobs route in main.dart.
// =========================================================================
class JobsPage extends StatelessWidget {
  final String initialQuery;
  const JobsPage({super.key, this.initialQuery = ''});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      toolbarHeight: Bp.navHeight,
      title: Text(
        'Explore jobs',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      actions: [
        if (!Session.instance.isSignedIn)
          TextButton(
            key: const ValueKey('jobs-sign-in'),
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('Sign in'),
          ),
        if (MediaQuery.sizeOf(context).width >= 600)
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: const AppBrand(),
          ),
      ],
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.surface,
    ),
    body: SafeArea(
      child: SingleChildScrollView(child: JobsView(initialQuery: initialQuery)),
    ),
  );
}

// =========================================================================
// Shared helpers (library-private, visible to every part file).
// =========================================================================

/// Reuses the board's detail flow, including its fresh listing request.
Future<void> showJobListing(
  BuildContext context,
  JobListing job, {
  List<JobOrganization> organizations = const [],
  JobAuthorizer? authorize,
  JobsApi? api,
}) async {
  final client = api ?? JobsApi();
  try {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: RouteSettings(name: '/jobs/${Uri.encodeComponent(job.id)}'),
        builder: (_) => _JobDetailPage(
          jobId: job.id,
          api: client,
          authorize: authorize ?? _authorizeJobs,
          organizations: organizations,
        ),
      ),
    );
  } finally {
    if (api == null) client.close();
  }
}

class JobDetailsPage extends StatefulWidget {
  final String jobId;
  final bool apply;
  const JobDetailsPage({super.key, required this.jobId, this.apply = false});
  @override
  State<JobDetailsPage> createState() => _JobDetailsPageHostState();
}

class _JobDetailsPageHostState extends State<JobDetailsPage> {
  final _api = JobsApi();
  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _JobDetailPage(
    jobId: widget.jobId,
    api: _api,
    authorize: _authorizeJobs,
    organizations: const [],
    applyOnOpen: widget.apply,
  );
}

Future<T> _authorizeJobs<T>(Future<T> Function(String token) call) async {
  final session = Session.instance;
  if (!session.isSignedIn) return call('');
  try {
    return await session.runAuthed(call);
  } on AuthException {
    if (!session.isSignedIn) return call('');
    rethrow;
  }
}

/// Card shadow used across the module (matches the dashboard's).
const _cardShadow = BoxShadow(
  color: Color(0x0D000000), // black @ 5%
  blurRadius: 24,
  offset: Offset(0, 10),
);

/// Error feedback for asynchronous listing actions.
void _demo(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
        content: Text(
          msg,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
}

/// Listing state and synthetic-data label shared by the card and detail.
class _JobBadge extends StatelessWidget {
  final String label;
  const _JobBadge(this.label);

  @override
  Widget build(BuildContext context) => AppStatusBadge(
    label: label,
    status: label == 'Synthetic demo' ? 'synthetic' : label,
  );
}
