part of '../dashboard_page.dart';

// =========================================================================
// Training destination (org Jobs view): the course catalog you can assign to
// your team, with completion tracked per offering.
// =========================================================================
class _TrainingScreen extends StatelessWidget {
  final List<_DashCourse> catalog;
  const _TrainingScreen(this.catalog);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Training',
          actionLabel: 'Assign',
          onAction: () => _demoAction(context),
        ),
        const SizedBox(height: 6),
        Text(
          '${catalog.length} active offerings',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        const _InfoNote(
          'Assign courses to your team and track completion in one place.',
        ),
        const SizedBox(height: 16),
        _OfferingGrid(catalog),
      ],
    );
  }
}
