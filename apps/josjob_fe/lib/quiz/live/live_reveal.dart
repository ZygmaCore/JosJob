part of '../quiz_page.dart';

/// The post-question feedback shown under the revealed grid: points earned (or
/// a gentle miss), the learner's new rank, and the explanation.
class _RevealPanel extends StatelessWidget {
  final int earned;
  final bool correct;
  final int rank;
  final int totalPlayers;
  final String explanation;
  const _RevealPanel({
    required this.earned,
    required this.correct,
    required this.rank,
    required this.totalPlayers,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (correct)
          _PointsBadge(earned, signed: true, big: true)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEBEB),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Text(
                  'No points this round',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: AppColors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              rank == 1
                  ? "You're in the lead!"
                  : "You're #$rank of $totalPlayers",
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.tintBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: AppColors.brandBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  explanation,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.navy,
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
