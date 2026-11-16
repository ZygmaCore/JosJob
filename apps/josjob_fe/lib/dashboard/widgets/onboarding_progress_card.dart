part of '../dashboard_page.dart';

// =========================================================================
// Shown at the top of the overview when the user finished the mandatory
// onboarding step but not the full flow (progress < 100). Prompts them to
// continue the optional sections; hidden once complete.
// =========================================================================
class _OnboardingProgressCard extends StatelessWidget {
  final int progress; // 0..100
  final VoidCallback onContinue;
  const _OnboardingProgressCard({
    required this.progress,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.tintBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: AppColors.brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish setting up your profile',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Complete onboarding to get better course and job matches.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressBar(value: progress / 100),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              label: 'Continue onboarding',
              icon: Icons.arrow_forward,
              variant: _PillVariant.tint,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}
