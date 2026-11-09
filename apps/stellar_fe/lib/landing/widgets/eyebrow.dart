part of '../landing_page_ascent.dart';

class _Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  final Color tint;
  const _Eyebrow(
    this.text, {
    this.color = AppColors.accent,
    this.tint = AppColors.tintBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
