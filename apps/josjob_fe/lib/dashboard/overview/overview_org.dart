part of '../dashboard_page.dart';

class _OverviewOrg extends StatelessWidget {
  final String? firstName;
  const _OverviewOrg({required this.firstName});

  @override
  Widget build(BuildContext context) => LearningOverviewView(
    organization: true,
    firstName: firstName,
    onUploadVideo: () => _uploadVod(context),
    onOpenCourse: (course) => _openLearningCourse(context, course),
  );
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
