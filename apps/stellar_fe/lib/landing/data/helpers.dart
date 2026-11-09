part of '../landing_page_ascent.dart';

bool _isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 768;
bool _zig(BuildContext c) => MediaQuery.sizeOf(c).width >= Bp.desktop;
bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;
Duration _anim(BuildContext c, [int ms = 220]) =>
    _reduceMotion(c) ? Duration.zero : Duration(milliseconds: ms);

double _gutter(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  if (w < 768) return 20;
  if (w < Bp.desktop) return 40;
  return 56;
}

TextStyle _display(BuildContext c, {Color color = AppColors.ink}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 34 : 54,
      height: 1.08,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.5,
    );

TextStyle _h2s(BuildContext c, {Color color = AppColors.ink}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 26 : 38,
      height: 1.12,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.5,
    );

TextStyle _lead(BuildContext c, {Color color = AppColors.body}) =>
    GoogleFonts.poppins(
      fontSize: _isMobile(c) ? 15.5 : 18,
      height: 1.6,
      fontWeight: FontWeight.w400,
      color: color,
    );
