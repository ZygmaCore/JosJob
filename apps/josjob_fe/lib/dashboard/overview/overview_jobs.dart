part of '../dashboard_page.dart';

// =========================================================================
// Overview screen for the JOBS view (AI Job Placement): a candidate's
// snapshot — placement stats, top matched roles, and an aside with the live
// application tracker split alongside profile strength + an AI career coach.
// Role-agnostic (the Learn/Jobs axis is independent of OnboardRole). Stub.
// =========================================================================
class _OverviewJobs extends StatelessWidget {
  final _DashboardData data;
  final String? firstName;
  const _OverviewJobs({required this.data, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final name = (firstName ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GreetingHeader(
          title: name.isEmpty ? 'Job placement preview' : 'Hi $name!',
          subtitle: 'Sample overview. Browse jobs for live opportunities.',
          trailing: const _OpenToWorkChip(),
        ),
        const SizedBox(height: 24),
        _StatGrid(data.stats),
        const SizedBox(height: 32),
        _SectionHeader(
          'Top matches for you',
          actionLabel: 'Browse all roles',
          onAction: () => _browseJobs(context),
        ),
        const SizedBox(height: 16),
        _JobMatchGrid(_jobMatches),
        const SizedBox(height: 32),
        _TwoColumn(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                'Your applications',
                actionLabel: 'View all',
                onAction: () => _demoAction(context),
              ),
              const SizedBox(height: 16),
              _ApplicationsCard(_applications),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _ProfileStrengthCard(),
              SizedBox(height: 24),
              _CareerCoachCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// Matched-role cards: 2-up when wide enough, else stacked.
class _JobMatchGrid extends StatelessWidget {
  final List<_JobMatch> jobs;
  const _JobMatchGrid(this.jobs);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 2 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final job in jobs)
              SizedBox(width: itemW, child: _JobMatchCard(job)),
          ],
        );
      },
    );
  }
}

// Small "Open to work" status chip shown beside the Jobs greeting.
class _OpenToWorkChip extends StatelessWidget {
  const _OpenToWorkChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 9, color: AppColors.iconGreen),
          const SizedBox(width: 6),
          Text(
            'Open to work',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.iconGreen,
            ),
          ),
        ],
      ),
    );
  }
}
