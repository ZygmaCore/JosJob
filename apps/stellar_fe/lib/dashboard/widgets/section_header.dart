part of '../dashboard_page.dart';

// =========================================================================
// Section title with an optional trailing text action (e.g. "View all").
// =========================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader(this.title, {this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          Semantics(
            button: true,
            label: actionLabel,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                actionLabel!,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
