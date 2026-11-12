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
  // JosJob landing page: Hallmark inspired Warm Cream × Deep Blue system.
  static const paper = Color(0xFFFFF8E9);
  static const paper2 = Color(0xFFF8EEDA);
  static const paper3 = Color(0xFFEFE3C8);
  static const cotton = Color(0xFFFFFDF7);
  static const desk = Color(0xFFF4EAD2);
  static const landingInk = Color(0xFF13213B);
  static const ink2 = Color(0xFF2A3A5C);
  static const muted = Color(0xFF586480);
  static const rule = Color(0xFFE3D8BF);
  static const rule2 = Color(0xFFD0C3A5);
  static const primary = Color(0xFF2457A7);
  static const primaryDeep = Color(0xFF183F7C);
  static const sky = Color(0xFF8EC5F0);
  static const amberGap = Color(0xFFF2B544);
  static const board = Color(0xFF0F2547);
  static const boardText = Color(0xFFFFF8E9);
  static const success = Color(0xFF1F7A5A);
  static const danger = Color(0xFFB83A2A);
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
