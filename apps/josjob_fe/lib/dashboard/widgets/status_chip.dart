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
    final (label, code) = switch (status) {
      _LearnerStatus.onTrack => ('On track', 'active'),
      _LearnerStatus.behind => ('Behind', 'pending'),
      _LearnerStatus.completed => ('Completed', 'completed'),
    };
    return AppStatusBadge(label: label, status: code);
  }
}
