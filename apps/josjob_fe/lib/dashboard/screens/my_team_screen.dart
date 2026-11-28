part of '../dashboard_page.dart';

// =========================================================================
// My team destination (org view): a summary of the roster by status, the
// full learner table, and an invite CTA.
// =========================================================================
class _MyTeamScreen extends StatelessWidget {
  final List<_Learner> roster;
  const _MyTeamScreen(this.roster);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'My team',
          actionLabel: 'Invite',
          onAction: () => _demoAction(context),
        ),
        const SizedBox(height: 6),
        Text(
          '${roster.length} learners',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _TeamSummary(roster),
        const SizedBox(height: 24),
        _LearnerTable(roster),
        const SizedBox(height: 16),
        const _InviteCard(),
      ],
    );
  }
}

// Responsive row of three status tiles: 3-up when wide, else stacked.
class _TeamSummary extends StatelessWidget {
  final List<_Learner> roster;
  const _TeamSummary(this.roster);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    final onTrack = roster
        .where((l) => l.status == _LearnerStatus.onTrack)
        .length;
    final behind = roster
        .where((l) => l.status == _LearnerStatus.behind)
        .length;
    final completed = roster
        .where((l) => l.status == _LearnerStatus.completed)
        .length;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 3 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemW,
              child: _TeamStat(
                count: onTrack,
                label: 'On track',
                tint: AppColors.tintGreen,
                fg: AppColors.iconGreen,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _TeamStat(
                count: behind,
                label: 'Behind',
                tint: AppColors.tintOrange,
                fg: AppColors.iconOrange,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _TeamStat(
                count: completed,
                label: 'Completed',
                tint: AppColors.tintBlue,
                fg: AppColors.brandBlue,
              ),
            ),
          ],
        );
      },
    );
  }
}

// A single status tile: a large tabular count over its label.
class _TeamStat extends StatelessWidget {
  final int count;
  final String label;
  final Color tint;
  final Color fg;
  const _TeamStat({
    required this.count,
    required this.label,
    required this.tint,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: _tabular(
                GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
          ),
        ],
      ),
    );
  }
}
