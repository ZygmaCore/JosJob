part of '../dashboard_page.dart';

class _OverviewIndividual extends StatelessWidget {
  final String? firstName;
  final VoidCallback onBrowseCourses;
  const _OverviewIndividual({
    required this.firstName,
    required this.onBrowseCourses,
  });

  @override
  Widget build(BuildContext context) => LearningOverviewView(
    firstName: firstName,
    onBrowseCourses: onBrowseCourses,
    onOpenCourse: (course) => _openLearningCourse(context, course),
  );
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
