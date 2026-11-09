part of '../dashboard_page.dart';

// =========================================================================
// Overview greeting: large navy title + body subtitle, with an optional
// trailing widget (e.g. the day-streak chip). Title scales down when narrow.
// =========================================================================
class _GreetingHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _GreetingHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: compact ? 24 : 28,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.body),
        ),
      ],
    );

    if (trailing == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: text),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}
