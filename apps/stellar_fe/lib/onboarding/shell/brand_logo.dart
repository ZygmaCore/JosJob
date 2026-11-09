part of '../onboarding_page.dart';

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Atveti Stellar',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.brandBlue, size: 22),
          const SizedBox(width: 8),
          Text(
            'Atveti Stellar',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}
