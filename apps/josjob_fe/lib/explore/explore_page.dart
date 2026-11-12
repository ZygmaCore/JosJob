import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show
        Stripe,
        CardField,
        CardEditController,
        PaymentMethodParams,
        PaymentMethodData,
        PaymentIntentsStatus,
        StripeException;

import '../theme/app_theme.dart';
import '../landing/landing_page_ascent.dart' show JosjobLandingPage;
import '../services/session.dart';
import '../services/courses_api.dart';

// =========================================================================
// JosJob — Explore Courses (course discovery / catalog)
//
// A catalog for the working professional: search by title / field / category
// and browse a responsive grid of gradient-thumbnail course cards. Reached
// from the landing "Programs" nav (route '/explore') and embedded in the
// dashboard "Courses" tab.
//
// Data is REAL: the catalog is fetched from GET /api/catalog/courses (the
// courses shared with the signed-in user's org). Only the fields the backend
// stores are shown — title, description, field(s), category (section) and
// class count; filtering (search + industry) and sorting run client-side.
//
// Responsive: desktop (>=1024) → 3-column grid; tablet → 2; mobile (<768) → 1.
// Thumbnails are gradient + Material-icon blocks (no image assets).
// Reduced-motion safe.
//
// Assembled from `part` files, one component per file, grouped under
// data/ shell/ widgets/. This library file owns every import and public
// symbol; part files carry no imports of their own.
// =========================================================================

// ---- data ---------------------------------------------------------------
part 'data/helpers.dart';
part 'data/models.dart';
part 'data/data.dart';

// ---- shell --------------------------------------------------------------
part 'shell/explore_shell.dart';
part 'shell/bounded.dart';
part 'shell/top_nav.dart';
part 'shell/logo.dart';
part 'shell/header.dart';
part 'shell/control_bar.dart';
part 'shell/footer.dart';
part 'shell/course_preview_sheet.dart';

// ---- widgets ------------------------------------------------------------
part 'widgets/pill_button.dart';
part 'widgets/tag_pill.dart';
part 'widgets/sort_pill.dart';
part 'widgets/search_field.dart';
part 'widgets/industry_filter.dart';
part 'widgets/course_grid.dart';
part 'widgets/course_card.dart';
part 'widgets/skeleton_card.dart';
part 'widgets/empty_state.dart';
part 'widgets/hover_lift.dart';

// =========================================================================
// Public entry point — imported by main.dart (route '/explore').
// =========================================================================
class ExploreCoursePage extends StatelessWidget {
  const ExploreCoursePage({super.key});

  @override
  Widget build(BuildContext context) => const _ExploreShell();
}

// =========================================================================
// Chrome-less catalog for embedding inside the dashboard's "Courses" tab.
// Renders the same browse experience without the standalone page's own top
// nav, footer or scroll view (the host dashboard provides those).
// =========================================================================
class ExploreCoursesView extends StatelessWidget {
  const ExploreCoursesView({super.key});

  @override
  Widget build(BuildContext context) => const _ExploreShell(embedded: true);
}
