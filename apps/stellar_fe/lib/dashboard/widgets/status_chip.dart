part of '../dashboard_page.dart';

// =========================================================================
// Small status pill for the learner table. Colour is paired with a text label
// (never colour alone) so it reads without relying on hue.
// =========================================================================
class _StatusChip extends StatelessWidget {
  final _LearnerStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (status) {
      _LearnerStatus.onTrack => (
        'On track',
        AppColors.tintGreen,
        AppColors.iconGreen,
      ),
      _LearnerStatus.behind => (
        'Behind',
        AppColors.tintOrange,
        AppColors.iconOrange,
      ),
      _LearnerStatus.completed => (
        'Completed',
        AppColors.tintBlue,
        AppColors.brandBlue,
      ),
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
