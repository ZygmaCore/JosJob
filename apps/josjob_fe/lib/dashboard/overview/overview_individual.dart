part of '../dashboard_page.dart';

// =========================================================================
// Overview screen for INDIVIDUAL roles (worker / graduate): a learner's
// snapshot — stats, continue learning, recommendations + weekly activity, and
// an aside with coaching, the AI assistant, and certificates.
// =========================================================================
class _OverviewIndividual extends StatelessWidget {
  final _DashboardData data;
  final String? firstName;
  final VoidCallback onBrowseCourses;
  const _OverviewIndividual({
    required this.data,
    required this.firstName,
    required this.onBrowseCourses,
  });

  @override
  Widget build(BuildContext context) {
    final name = (firstName ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GreetingHeader(
          title: name.isEmpty ? 'Welcome back!' : 'Welcome back, $name!',
          subtitle: "Here's your learning snapshot",
        ),
        const SizedBox(height: 24),
        _StatGrid(data.stats),
        const SizedBox(height: 32),
        _SectionHeader(
          'Continue learning',
          actionLabel: 'Take a quiz',
          onAction: () => _quiz(context),
        ),
        const SizedBox(height: 16),
        _ContinueLearningRow(data.continueLearning),
        const SizedBox(height: 32),
        _TwoColumn(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                'Recommended for you',
                actionLabel: 'Browse',
                onAction: onBrowseCourses,
              ),
              const SizedBox(height: 16),
              _RecommendedGrid(data.recommended),
              const SizedBox(height: 24),
              _WeeklyActivityCard(data.weeklyHours),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UpNextCard(data.coaching.take(2).toList()),
              const SizedBox(height: 24),
              const _AiAssistantCard(),
              const SizedBox(height: 24),
              _CertificatesCard(data.certificates),
            ],
          ),
        ),
      ],
    );
  }
}

// Continue-learning cards: 3-up wide, 2-up medium, stacked on mobile.
class _ContinueLearningRow extends StatelessWidget {
  final List<_DashCourse> courses;
  const _ContinueLearningRow(this.courses);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 940
            ? 3
            : w >= 620
            ? 2
            : 1;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final course in courses)
              SizedBox(width: itemW, child: _CourseProgressCard(course)),
          ],
        );
      },
    );
  }
}

// Recommended cards grid: 2-up when wide enough, else stacked.
class _RecommendedGrid extends StatelessWidget {
  final List<_DashCourse> courses;
  const _RecommendedGrid(this.courses);

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
            for (final course in courses)
              SizedBox(width: itemW, child: _RecommendedCourseCard(course)),
          ],
        );
      },
    );
  }
}

// Shared main/aside two-column layout: side-by-side on desktop, stacked below.
class _TwoColumn extends StatelessWidget {
  final Widget main;
  final Widget aside;
  const _TwoColumn({required this.main, required this.aside});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: aside),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [main, const SizedBox(height: 24), aside],
        );
      },
    );
  }
}
