part of '../quiz_page.dart';

/// Live poll — quick, unscored feedback. Voting shows tappable options; the
/// result view animates the bars with live-updating tallies (the learner's own
/// vote is folded into the counts and highlighted).
class _LivePollView extends StatelessWidget {
  final _Poll poll;
  final int remaining;
  final bool showResult;
  final int? selected;
  final ValueChanged<int> onVote;
  const _LivePollView({
    required this.poll,
    required this.remaining,
    required this.showResult,
    required this.selected,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final youVoted = selected != null;
    final counts = [
      for (var i = 0; i < poll.options.length; i++)
        poll.tally[i] + (selected == i ? 1 : 0),
    ];
    final total = poll.total + (youVoted ? 1 : 0);

    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  _TagPill(
                    'Live poll',
                    fg: AppColors.iconOrange,
                    bg: AppColors.tintOrange,
                    icon: Icons.how_to_vote_outlined,
                  ),
                  const Spacer(),
                  if (showResult)
                    _StatChip(
                      Icons.groups_outlined,
                      '$total votes',
                      color: AppColors.navy,
                    )
                  else
                    _StatChip(
                      Icons.timer_outlined,
                      '${remaining}s',
                      color: AppColors.navy,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                poll.prompt,
                style: GoogleFonts.poppins(
                  fontSize: _isMobile(context) ? 20 : 24,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < poll.options.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PollBar(
                  label: poll.options[i],
                  votes: counts[i],
                  fraction: total == 0 ? 0 : counts[i] / total,
                  selected: selected == i,
                  revealed: showResult,
                  onTap: (!showResult && !youVoted) ? () => onVote(i) : null,
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text(
                  showResult
                      ? 'Results update live · no score for polls'
                      : youVoted
                      ? 'Vote locked — tallying…'
                      : 'Tap an option to cast your vote',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
