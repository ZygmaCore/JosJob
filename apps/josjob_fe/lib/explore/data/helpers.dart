part of '../explore_page.dart';

// -------------------------------------------------------------------------
// Library-private shared helpers (responsive, motion, type, formatting) —
// visible to every part file. Mirrors the landing/onboarding conventions.
// -------------------------------------------------------------------------
bool _isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 768;
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
      fontSize: _isMobile(c) ? 28 : 40,
      height: 1.12,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.5,
    );

TextStyle _lead(BuildContext c, {Color color = AppColors.body}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 15.5 : 17,
      height: 1.6,
      fontWeight: FontWeight.w400,
      color: color,
    );

/// Standard "no backend yet" feedback for demo-only actions (navy floating
/// snackbar, matching the dashboard module).
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
