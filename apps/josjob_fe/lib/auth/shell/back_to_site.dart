part of '../auth_page.dart';

class _BackToSite extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToSite({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to site',
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.body),
        label: Text(
          'Back to site',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.body,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
