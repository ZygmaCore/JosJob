part of '../dashboard_page.dart';

// =========================================================================
// Reusable empty state: centered icon tile, title, subtitle and an optional
// action. Used by placeholder panels and available anywhere a list is empty.
// =========================================================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: icon,
      title: title,
      message: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
