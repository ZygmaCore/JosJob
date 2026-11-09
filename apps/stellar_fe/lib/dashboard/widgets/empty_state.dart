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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.tintBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: AppColors.iconBlue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.body,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            _PillButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: _PillVariant.tint,
            ),
          ],
        ],
      ),
    );
  }
}
