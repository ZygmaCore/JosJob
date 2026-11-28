part of '../quiz_page.dart';

/// "Question X of N" label over an animated linear progress track. Optionally
/// shows a trailing element (e.g. the elapsed-time chip) on the same row.
class _QuizProgressBar extends StatelessWidget {
  final int current; // 1-based
  final int total;
  final Widget? trailing;
  const _QuizProgressBar({
    required this.current,
    required this.total,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (current / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Question $current of $total',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Stack(
            children: [
              Container(height: 8, color: AppColors.border),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: _anim(context, 420),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.brandBlue, AppColors.accent],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
