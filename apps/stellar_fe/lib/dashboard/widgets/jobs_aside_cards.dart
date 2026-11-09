part of '../dashboard_page.dart';

// =========================================================================
// Aside cards for the Jobs overview: profile-strength meter + checklist, and
// an AI career-coach promo (the placement-side counterpart of the learning
// AI teaching-assistant card).
// =========================================================================
class _ProfileStrengthCard extends StatelessWidget {
  const _ProfileStrengthCard();

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tintBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.iconBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Profile strength',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Text(
                '82%',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: 0.82,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 18),
          const _ChecklistRow('Skills & experience added', done: true),
          const _ChecklistRow('Certifications verified', done: true),
          const _ChecklistRow('Add a portfolio link', done: false),
          const SizedBox(height: 16),
          _PillButton(
            label: 'Complete profile',
            variant: _PillVariant.tint,
            onPressed: () => _demoAction(context),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;
  const _ChecklistRow(this.label, {required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.iconGreen : AppColors.border,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: done ? AppColors.body : AppColors.ink,
                fontWeight: done ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Placement-side AI promo — mirrors _AiAssistantCard's navy gradient styling.
class _CareerCoachCard extends StatelessWidget {
  const _CareerCoachCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [_cardShadow],
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.brandBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Career Coach',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Get help with your profile, resume and interview prep, 24/7.',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.onNavyDim,
            ),
          ),
          const SizedBox(height: 18),
          _AskAiButton(onPressed: () => _demoAction(context)),
        ],
      ),
    );
  }
}
