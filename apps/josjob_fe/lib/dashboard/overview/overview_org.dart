part of '../dashboard_page.dart';

// =========================================================================
// Overview screen for ORG roles (employer / coordinator): the organization's
// snapshot — stats, team progress + invite CTA, training offerings + completion
// overview, and an aside with coaching, the AI assistant, and an activity feed.
// =========================================================================
class _OverviewOrg extends StatelessWidget {
  final _DashboardData data;
  final String? firstName;
  const _OverviewOrg({required this.data, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final name = (firstName ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GreetingHeader(
          title: name.isEmpty ? 'Welcome!' : 'Welcome, $name',
          subtitle: 'Your organization overview',
        ),
        const SizedBox(height: 24),
        _StatGrid(data.stats),
        const SizedBox(height: 32),
        _SectionHeader(
          'Team progress',
          actionLabel: 'Invite',
          onAction: () => _demoAction(context),
        ),
        const SizedBox(height: 16),
        _LearnerTable(data.learners),
        const SizedBox(height: 16),
        const _InviteCard(),
        const SizedBox(height: 32),
        _TwoColumn(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                'Training offerings',
                actionLabel: 'Upload video',
                onAction: () => _uploadVod(context),
              ),
              const SizedBox(height: 16),
              _OfferingGrid(data.offerings),
              const SizedBox(height: 24),
              _CompletionOverviewCard(data.completionByCourse),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UpNextCard(data.coaching),
              const SizedBox(height: 24),
              const _AiAssistantCard(),
              const SizedBox(height: 24),
              _ActivityFeedCard(data.activity),
            ],
          ),
        ),
      ],
    );
  }
}

// Offerings grid: 2-up when wide enough, else stacked.
class _OfferingGrid extends StatelessWidget {
  final List<_DashCourse> offerings;
  const _OfferingGrid(this.offerings);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 2 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final o in offerings)
              SizedBox(width: itemW, child: _OfferingCard(o)),
          ],
        );
      },
    );
  }
}
