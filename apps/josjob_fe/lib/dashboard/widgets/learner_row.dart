part of '../dashboard_page.dart';

// =========================================================================
// A learner row in the team table. Reflows to two lines when narrow so the
// progress bar and status never crowd on mobile.
// =========================================================================
class _LearnerRow extends StatelessWidget {
  final _Learner learner;
  const _LearnerRow(this.learner);

  @override
  Widget build(BuildContext context) {
    final identity = Row(
      children: [
        _Avatar(name: learner.name, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                learner.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                learner.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 460;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 10),
                  _StatusChip(learner.status),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressBar(value: learner.progress),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 5, child: identity),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _ProgressBar(value: learner.progress)),
            const SizedBox(width: 16),
            SizedBox(
              width: 96,
              child: Align(
                alignment: Alignment.centerRight,
                child: _StatusChip(learner.status),
              ),
            ),
          ],
        );
      },
    );
  }
}
