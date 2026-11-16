part of '../quiz_page.dart';

/// "How progression works" — a compact visualisation of the assessment journey
/// (placement → path → lecture gates → section gate → credential). Horizontal
/// with arrow connectors on desktop; a stacked list on mobile.
class _ProgressionBand extends StatelessWidget {
  const _ProgressionBand();

  static const _steps = <(IconData, String, String, Color)>[
    (
      Icons.explore_outlined,
      'Placement',
      'Map your baseline skills',
      AppColors.iconBlue,
    ),
    (
      Icons.route_outlined,
      'Learning path',
      'Personalised to your gaps',
      AppColors.brandBlue,
    ),
    (
      Icons.play_lesson_outlined,
      'Lecture quiz',
      'Pass 70% to unlock the next',
      AppColors.brandBlue,
    ),
    (
      Icons.workspace_premium_outlined,
      'Section quiz',
      'Pass 75% to unlock the next',
      AppColors.iconGreen,
    ),
    (
      Icons.verified_outlined,
      'Credential',
      'Complete the course',
      AppColors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      padding: EdgeInsets.all(desktop ? 26 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_outlined,
                size: 20,
                color: AppColors.brandBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How progression works',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (desktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: AppColors.border,
                      ),
                    ),
                  Expanded(child: _stepTile(_steps[i], vertical: true)),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: AppColors.border,
                      ),
                    ),
                  _stepTile(_steps[i], vertical: false),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _stepTile(
    (IconData, String, String, Color) s, {
    required bool vertical,
  }) {
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: s.$4.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(s.$1, color: s.$4, size: 22),
    );
    final title = Text(
      s.$2,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
    final sub = Text(
      s.$3,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.35,
        color: AppColors.body,
      ),
    );

    if (vertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 10),
            title,
            const SizedBox(height: 4),
            Align(alignment: Alignment.center, child: sub),
          ],
        ),
      );
    }
    return Row(
      children: [
        icon,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 2), sub],
          ),
        ),
      ],
    );
  }
}
