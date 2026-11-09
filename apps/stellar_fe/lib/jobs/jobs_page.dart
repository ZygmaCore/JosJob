import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

// =========================================================================
// ATVETI STELLAR — Jobs board (AI Job Placement)  ·  UI only, no backend
//
// The standalone browse-roles surface reached from the dashboard's Jobs view
// ("Browse all roles") and the landing "Jobs" nav, registered at /jobs. A
// searchable (stub) list of matched roles → a role detail screen. All data is
// hard-coded sample content; the design system (AppColors, Poppins, pill
// buttons, rounded cards) is shared with the rest of the app.
//
// One library assembled from `part` files; this file owns every import and the
// public entry widget. Part files carry no imports of their own.
// =========================================================================

part 'data/models.dart';
part 'data/jobs_data.dart';
part 'widgets/search_field.dart';
part 'widgets/job_card.dart';
part 'screens/job_board.dart';
part 'screens/job_detail.dart';

// =========================================================================
// Public entry point — registered as the /jobs route in main.dart.
// =========================================================================
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) => const _JobBoard();
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

/// Standard "no backend" feedback for demo-only buttons.
void _demo(BuildContext c, [String msg = 'Demo — no backend yet.']) {
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

/// Green match-score pill, e.g. "96% match". Shared by the card and detail.
class _MatchBadge extends StatelessWidget {
  final int pct;
  const _MatchBadge(this.pct);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pct% match',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.iconGreen,
        ),
      ),
    );
  }
}
