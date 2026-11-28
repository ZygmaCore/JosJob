part of '../onboarding_page.dart';

// =========================================================================
// Top bar — brand + step progress
// =========================================================================
class _TopBar extends StatelessWidget {
  final bool showProgress;
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  const _TopBar({
    required this.showProgress,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _compact(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 12, compact ? 12 : 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  tooltip: 'Back',
                ),
              ),
              const SizedBox(width: 4),
              const _BrandLogo(),
              const Spacer(),
              if (showProgress)
                Text(
                  'Step ${step + 1} of $totalSteps',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.body,
                  ),
                ),
              if (onSkip != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Skip onboarding',
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            _SegmentedProgress(step: step, total: totalSteps),
          ],
        ],
      ),
    );
  }
}
