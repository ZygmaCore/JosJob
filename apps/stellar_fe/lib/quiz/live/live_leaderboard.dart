part of '../quiz_page.dart';

/// The room leaderboard — the top of the room between questions, and the final
/// standings at the end (with play-again / exit actions).
class _LiveLeaderboard extends StatelessWidget {
  final List<_Player> players; // pre-sorted, descending by score
  final int yourRank;
  final bool finished;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onExit;
  const _LiveLeaderboard({
    required this.players,
    required this.yourRank,
    required this.finished,
    this.onPlayAgain,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final maxScore = players.fold<int>(1, (m, p) => math.max(m, p.score));
    final top = players.take(5).toList();
    final showYouSeparately = yourRank > top.length;
    final you = players.firstWhere(
      (p) => p.isYou,
      orElse: () => const _Player('You', 0, isYou: true),
    );

    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    finished ? Icons.emoji_events : Icons.leaderboard,
                    color: AppColors.orange,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    finished ? 'Final results' : 'Leaderboard',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              if (finished) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandBlue, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        yourRank == 1 ? 'You won!' : 'Nice work!',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You finished #$yourRank of ${players.length} with ${_fmtPts(you.score)} points',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'Top of the room',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: AppColors.body,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              for (var i = 0; i < top.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _LeaderboardRow(
                  rank: i + 1,
                  player: top[i],
                  maxScore: maxScore,
                ),
              ],
              if (showYouSeparately) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '•••',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppColors.body,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _LeaderboardRow(
                  rank: yourRank,
                  player: you,
                  maxScore: maxScore,
                ),
              ],
              if (finished) ...[
                const SizedBox(height: 26),
                if (mobile)
                  Column(
                    children: [
                      _PillButton(
                        'Play again',
                        leading: Icons.refresh,
                        expand: true,
                        onPressed: onPlayAgain,
                      ),
                      const SizedBox(height: 12),
                      _PillButton(
                        'Exit',
                        kind: _BtnKind.ghost,
                        expand: true,
                        onPressed: onExit,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      _PillButton(
                        'Exit',
                        kind: _BtnKind.ghost,
                        onPressed: onExit,
                      ),
                      const Spacer(),
                      _PillButton(
                        'Play again',
                        leading: Icons.refresh,
                        onPressed: onPlayAgain,
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
