import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brandBlue),
  );
  final text = GoogleFonts.poppinsTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.navy);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  );
  final buttonText = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  final buttonFeedback = ButtonStyle(
    animationDuration: const Duration(milliseconds: 180),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.focused)) {
        return AppColors.brandBlue.withValues(alpha: 0.13);
      }
      if (states.contains(WidgetState.pressed)) {
        return AppColors.brandBlue.withValues(alpha: 0.1);
      }
      if (states.contains(WidgetState.hovered)) {
        return AppColors.brandBlue.withValues(alpha: 0.055);
      }
      return null;
    }),
    backgroundBuilder: (context, states, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final pressed = states.contains(WidgetState.pressed) && !reduceMotion;
      return AnimatedScale(
        scale: pressed ? 0.975 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: child,
      );
    },
  );
  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const _InstantPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.brandBlue,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tintBlue,
      onPrimaryContainer: AppColors.navy,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      outline: AppColors.border,
    ),
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: shape,
                textStyle: buttonText,
              )
              .merge(buttonFeedback)
              .copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? const BorderSide(color: AppColors.brandBlue, width: 2)
                      : BorderSide.none,
                ),
              ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: shape,
                side: const BorderSide(color: AppColors.border),
                textStyle: buttonText,
              )
              .merge(buttonFeedback)
              .copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? const BorderSide(color: AppColors.brandBlue, width: 2)
                      : const BorderSide(color: AppColors.border),
                ),
              ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: shape,
                textStyle: buttonText,
              )
              .merge(buttonFeedback)
              .copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? const BorderSide(color: AppColors.brandBlue, width: 1.5)
                      : BorderSide.none,
                ),
              ),
    ),
    iconButtonTheme: IconButtonThemeData(style: buttonFeedback),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
      ),
      errorBorder: field.copyWith(
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorMaxLines: 3,
      helperMaxLines: 3,
      labelStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.tintBlue,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      shape: shape,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

// =========================================================================
// Shared design tokens for the JosJob frontend
// (Online Learning + AI Job Placement).
//
// Single source of truth for the blue palette and responsive breakpoints,
// consumed by the landing, auth, onboarding and dashboard modules. The
// landing library re-exports this file, so existing
// `import 'landing_page_ascent.dart' show AppColors, Bp;` imports keep
// working unchanged.
// =========================================================================

class AppColors {
  // Landing reference palette: cool gray surfaces, deep navy type, bright blue.
  static const paper = Color(0xFFF4F7FA);
  static const paper2 = Color(0xFFEDF2F8);
  static const paper3 = Color(0xFFE5EDF7);
  static const cotton = Color(0xFFFFFFFF);
  static const desk = Color(0xFFEAF3FC);
  static const landingInk = Color(0xFF112B4E);
  static const ink2 = Color(0xFF253F60);
  static const muted = Color(0xFF5F7187);
  static const rule = Color(0xFFE0E7EF);
  static const rule2 = Color(0xFFCBD6E3);
  static const primary = Color(0xFF1877D4);
  static const primaryDeep = Color(0xFF1264B5);
  static const sky = Color(0xFFE5F2FF);
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
