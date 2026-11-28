part of '../dashboard_page.dart';

// =========================================================================
// Card wrapping the team's learner rows, with a divider between each. Shows
// the shared empty state when there are no learners.
// =========================================================================
class _LearnerTable extends StatelessWidget {
  final List<_Learner> learners;
  const _LearnerTable(this.learners);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: learners.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: _EmptyState(
                icon: Icons.groups_outlined,
                title: 'No learners yet',
                subtitle: 'Invite your team to start tracking progress.',
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < learners.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _LearnerRow(learners[i]),
                  ),
                ],
              ],
            ),
    );
  }
}
