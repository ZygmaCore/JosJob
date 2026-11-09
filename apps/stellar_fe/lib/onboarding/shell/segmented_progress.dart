part of '../onboarding_page.dart';

class _SegmentedProgress extends StatelessWidget {
  final int step;
  final int total;
  const _SegmentedProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: _reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.brandBlue : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
