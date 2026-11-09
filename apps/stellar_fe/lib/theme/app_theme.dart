import 'package:flutter/material.dart';

// =========================================================================
// Shared design tokens for the Atveti Stellar unified frontend
// (Online Learning + AI Job Placement).
//
// Single source of truth for the blue palette and responsive breakpoints,
// consumed by the landing, auth, onboarding and dashboard modules. The
// landing library re-exports this file, so existing
// `import 'landing_page_ascent.dart' show AppColors, Bp;` imports keep
// working unchanged.
// =========================================================================

class AppColors {
  static const heroBlue = Color(0xFF1385E0);
  static const brandBlue = Color(0xFF1877D4);
  static const accent = Color(0xFF1E9BF0);
  static const navy = Color(0xFF0F2C4D);
  static const ink = Color(0xFF0E1B2A);
  static const body = Color(0xFF5B6B7B);
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6EAF0);
  static const focus = Color(0x552E86DE); // visible keyboard-focus overlay
  static const onNavyDim = Color(
    0xFFC7D2DE,
  ); // ~9:1 on navy — AA-safe secondary
  static const tintBlue = Color(0xFFE7F1FB);
  static const tintOrange = Color(0xFFFDECDD);
  static const tintGreen = Color(0xFFE3F3E9);
  static const iconBlue = Color(0xFF2E86DE);
  static const iconOrange = Color(0xFFE8873B);
  static const iconGreen = Color(0xFF3EA76A);
  static const orange = Color(0xFFF2913D);
}

class Bp {
  static const double desktop = 1024;
  static const double maxContent = 1180;
  static const double navHeight = 76;
  static const double channel = 92;
  static const double railInset = 26;
}
