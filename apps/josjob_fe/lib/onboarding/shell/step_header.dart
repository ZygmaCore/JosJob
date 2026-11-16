part of '../onboarding_page.dart';

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: _compact(context) ? 24 : 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.55,
            color: AppColors.body,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
