part of '../quiz_page.dart';

/// One leaderboard entry: rank medal, initials avatar, name (with a "You" tag),
/// an optional score bar, and the tabular point total. The learner's own row
/// is tinted and outlined so it is easy to spot.
class _LeaderboardRow extends StatelessWidget {
  final int rank; // 1-based
  final _Player player;
  final int maxScore;
  const _LeaderboardRow({
    required this.rank,
    required this.player,
    required this.maxScore,
  });

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Color get _medal => switch (rank) {
    1 => AppColors.orange,
    2 => const Color(0xFF8FA3B8),
    3 => const Color(0xFFB9825B),
    _ => AppColors.navy,
  };

  @override
  Widget build(BuildContext context) {
    final you = player.isYou;
    final fraction = maxScore <= 0
        ? 0.0
        : (player.score / maxScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: you ? AppColors.tintBlue : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: you ? AppColors.brandBlue : AppColors.border,
          width: you ? 1.6 : 1.2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: _medal, size: 24)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: _tabular(
                      GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.body,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 17,
            backgroundColor: you ? AppColors.brandBlue : AppColors.navy,
            child: Text(
              _initials(player.name),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    if (you) ...[
                      const SizedBox(width: 8),
                      const _TagPill(
                        'You',
                        fg: Colors.white,
                        bg: AppColors.brandBlue,
                      ),
                    ],
                  ],
                ),
                ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      children: [
                        Container(height: 6, color: AppColors.border),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fraction),
                          duration: _anim(context, 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: v,
                            child: Container(
                              height: 6,
                              color: you ? AppColors.brandBlue : _medal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _fmtPts(player.score),
            style: _tabular(
              GoogleFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
