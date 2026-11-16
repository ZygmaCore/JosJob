part of '../quiz_page.dart';

/// Dual-purpose live-poll row.
///  • Voting (revealed == false): a tappable option with a radio indicator.
///  • Results (revealed == true): an animated horizontal bar with the label,
///    vote count and percentage; the learner's own choice is highlighted.
class _PollBar extends StatelessWidget {
  final String label;
  final int votes;
  final double fraction; // 0..1 of total votes
  final bool selected;
  final bool revealed;
  final VoidCallback? onTap;
  const _PollBar({
    required this.label,
    required this.votes,
    required this.fraction,
    required this.selected,
    required this.revealed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.tintBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            focusColor: AppColors.focus,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.brandBlue : AppColors.border,
                  width: selected ? 2 : 1.4,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.brandBlue : AppColors.body,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Results bar.
    final pct = (fraction * 100).round();
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.brandBlue : AppColors.border,
          width: selected ? 1.8 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: _anim(context, 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(
                  color: (selected ? AppColors.brandBlue : AppColors.accent)
                      .withValues(alpha: selected ? 0.22 : 0.14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$pct%',
                  style: _tabular(
                    GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($votes)',
                  style: _tabular(
                    GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
