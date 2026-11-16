part of '../onboarding_page.dart';

// =========================================================================
// Skip-onboarding confirmation
// =========================================================================
class _SkipDialog extends StatelessWidget {
  const _SkipDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Skip setup?',
        style: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: Text(
        'You can complete your profile and pick training later from your '
        'dashboard.',
        style: GoogleFonts.poppins(
          fontSize: 14.5,
          height: 1.5,
          color: AppColors.body,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          child: Text(
            'Keep setting up',
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandBlue,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          child: Text(
            'Skip for now',
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
