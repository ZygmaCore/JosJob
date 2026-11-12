part of '../dashboard_page.dart';

// =========================================================================
// Reports destination (ORG view): a KPI snapshot, enrollment trend, course
// completion breakdown, and a live activity feed.
// =========================================================================
class _ReportsScreen extends StatelessWidget {
  final _DashboardData data;
  const _ReportsScreen(this.data);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Reports',
          actionLabel: 'Export',
          onAction: () => _demoAction(context),
        ),
        const SizedBox(height: 16),
        _StatGrid(_reportStats),
        const SizedBox(height: 32),
        _TwoColumn(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ReportChartCard(),
              const SizedBox(height: 24),
              _CompletionOverviewCard(data.completionByCourse),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_ActivityFeedCard(data.activity)],
          ),
        ),
      ],
    );
  }
}

// New-enrollments trend chart, wrapped in a card with a titled header.
class _ReportChartCard extends StatelessWidget {
  const _ReportChartCard();

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New enrollments',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Last 6 months',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
          ),
          const SizedBox(height: 20),
          _MiniBarChart(values: _reportEnrollments, labels: _reportMonths),
        ],
      ),
    );
  }
}
