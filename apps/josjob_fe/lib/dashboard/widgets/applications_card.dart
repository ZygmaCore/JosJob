part of '../dashboard_page.dart';

// Pipeline-stage pill; colour is always paired with a label (never hue alone).
class _StageChip extends StatelessWidget {
  final _AppStage stage;
  const _StageChip(this.stage);

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (stage) {
      _AppStage.applied => ('Applied', AppColors.tintBlue, AppColors.brandBlue),
      _AppStage.screening => (
        'Screening',
        AppColors.tintOrange,
        AppColors.iconOrange,
      ),
      _AppStage.interview => (
        'Interview',
        AppColors.tintGreen,
        AppColors.iconGreen,
      ),
      _AppStage.offer => ('Offer', AppColors.tintGreen, AppColors.iconGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
