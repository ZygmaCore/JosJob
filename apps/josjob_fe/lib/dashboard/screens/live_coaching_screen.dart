part of '../dashboard_page.dart';

// =========================================================================
// Live Coaching destination (learner Learn view): your booked sessions plus
// a searchable "Explore coaches" browser (search + focus filters + sort) —
// no separate page.
// =========================================================================
class _LiveCoachingScreen extends StatelessWidget {
  const _LiveCoachingScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enrollment-gated: a learner can only see & join live sessions for the
        // classes they're actually enrolled in (GET /api/me/enrollments).
        const _EnrolledClassesCard(),
        const SizedBox(height: 28),
        const _SectionHeader('Your sessions'),
        const SizedBox(height: 16),
        _UpNextCard(_sharedCoaching),
        const SizedBox(height: 32),
        const _SectionHeader('Explore coaches'),
        const SizedBox(height: 6),
        Text(
          'Book one-on-one time with a coach matched to your goals.',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _CoachBrowser(_exploreCoaches),
      ],
    );
  }
}
