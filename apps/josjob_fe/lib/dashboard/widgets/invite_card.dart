part of '../dashboard_page.dart';

// =========================================================================
// Call-to-action tile inviting the org to add their team. Tinted background
// to stand apart from the neutral cards.
// =========================================================================
class _InviteCard extends StatelessWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_add_alt_1_outlined,
              color: AppColors.iconBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite your team',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Register learners to assign training and track their progress.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: 'Invite learners',
                  icon: Icons.add,
                  onPressed: () => _demoAction(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
