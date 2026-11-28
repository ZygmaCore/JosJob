part of '../auth_page.dart';

/// Monochrome "G" mark (no official Google asset bundled — neutral placeholder).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: GoogleFonts.poppins(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}
