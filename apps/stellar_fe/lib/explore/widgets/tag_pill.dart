part of '../explore_page.dart';

/// Small rounded label for eyebrows, category and level tags. Defaults to the
/// module's tintBlue/iconBlue treatment; pass [fg]/[bg] for category colours.
class _TagPill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const _TagPill(
    this.text, {
    this.fg = AppColors.iconBlue,
    this.bg = AppColors.tintBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: fg,
        ),
      ),
    );
  }
}
