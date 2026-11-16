part of '../dashboard_page.dart';

// =========================================================================
// "Live coaching" aside card listing upcoming coaching sessions.
// =========================================================================
class _UpNextCard extends StatelessWidget {
  final List<_Mentor> mentors;
  const _UpNextCard(this.mentors);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.videocam_outlined,
                size: 20,
                color: AppColors.iconBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live coaching',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < mentors.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
            ],
            _CoachingTile(mentors[i]),
          ],
        ],
      ),
    );
  }
}
