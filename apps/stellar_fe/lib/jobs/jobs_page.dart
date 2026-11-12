import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/jobs_api.dart';
import '../services/session.dart';

// =========================================================================
// JOSJOB — Authenticated job browsing and employer listing management.
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
part 'screens/job_detail.dart';
part 'screens/job_editor.dart';

// =========================================================================
// Public entry point — registered as the /jobs route in main.dart.
// =========================================================================
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text('Jobs'),
      backgroundColor: AppColors.surface,
    ),
    body: const SafeArea(child: SingleChildScrollView(child: JobsView())),
  );
}

// =========================================================================
// Shared helpers (library-private, visible to every part file).
// =========================================================================

/// Card shadow used across the module (matches the dashboard's).
const _cardShadow = BoxShadow(
  color: Color(0x0D000000), // black @ 5%
  blurRadius: 24,
  offset: Offset(0, 10),
);

/// Deterministic company-logo gradient keyed by a small seed.
LinearGradient _logoGradient(int seed) {
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

/// Initials from a company name, e.g. "Hospitality Group" -> "HG".
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.iconGreen,
        ),
      ),
    );
  }
}
