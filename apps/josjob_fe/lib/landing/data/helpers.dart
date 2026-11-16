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

TextStyle _display(BuildContext c, {Color color = AppColors.landingInk}) =>
    TextStyle(
      fontFamily: 'General Sans',
      fontSize: _isMobile(c) ? 38 : 62,
      height: 1.04,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: -1.8,
    );

TextStyle _h2s(BuildContext c, {Color color = AppColors.landingInk}) =>
    TextStyle(
      fontFamily: 'General Sans',
      fontSize: _isMobile(c) ? 28 : 42,
      height: 1.06,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: -1.1,
    );

TextStyle _lead(BuildContext c, {Color color = AppColors.muted}) => TextStyle(
  fontFamily: 'General Sans',
  fontSize: _isMobile(c) ? 15.5 : 18,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: color,
);
