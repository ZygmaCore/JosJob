part of '../landing_page_ascent.dart';

class _Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  final Color tint;
  const _Eyebrow(
    this.text, {
    this.color = AppColors.primary,
    this.tint = AppColors.paper2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'General Sans',
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
