part of '../quiz_page.dart';

// -------------------------------------------------------------------------
// Library-private shared helpers (responsive, motion, type, formatting),
// visible to every part file. Mirrors the landing / explore conventions.
// -------------------------------------------------------------------------
bool _isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 768;
bool _isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= Bp.desktop;
bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;
Duration _anim(BuildContext c, [int ms = 220]) =>
    _reduceMotion(c) ? Duration.zero : Duration(milliseconds: ms);

double _gutter(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  if (w < 768) return 20;
  if (w < Bp.desktop) return 40;
  return 56;
}

TextStyle _h2s(BuildContext c, {Color color = AppColors.ink}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 27 : 38,
      height: 1.14,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.5,
    );

TextStyle _lead(BuildContext c, {Color color = AppColors.body}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 15 : 16.5,
      height: 1.6,
      fontWeight: FontWeight.w400,
      color: color,
    );

/// Tabular figures for timers, scores and points, so counting up/down never
/// nudges the surrounding layout.
TextStyle _tabular(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Thousands separator for point totals, e.g. 1240 -> "1,240".
String _fmtPts(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Standard "no backend yet" feedback for demo-only actions (navy floating
/// snackbar, matching the dashboard / explore modules).
void _soon(BuildContext c, String message) {
  ScaffoldMessenger.of(c)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
}

/// Card shadow used across the module (matches the dashboard elevation).
const _cardShadow = BoxShadow(
  color: Color(0x0D000000), // black @ 5%
  blurRadius: 24,
  offset: Offset(0, 10),
);

// ---- Live-quiz answer palette -------------------------------------------
// Four visually distinct option identities. Colour is NEVER the only signal:
// every tile also carries a unique [shape] glyph and its letter, so the grid
// stays legible for colour-blind learners. Foregrounds are chosen for >=3:1
// contrast against their fill (large, bold option text).
class _OptColor {
  final Color bg;
  final Color fg;
  final IconData shape;
  const _OptColor(this.bg, this.fg, this.shape);
}

const _livePalette = <_OptColor>[
  _OptColor(Color(0xFF1877D4), Colors.white, Icons.change_history), // triangle
  _OptColor(Color(0xFF6D28D9), Colors.white, Icons.diamond), // diamond
  _OptColor(Color(0xFF0E7C86), Colors.white, Icons.circle), // circle
  _OptColor(Color(0xFFE8873B), AppColors.navy, Icons.square), // square
];
