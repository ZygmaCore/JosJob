part of '../dashboard_page.dart';

// =========================================================================
// A bookable coach: avatar, name + expertise, tagline, rating and a
// "Book session" action. Shown in Live Coaching → Explore coaches.
// =========================================================================
class _CoachCard extends StatelessWidget {
  final _Coach coach;
  const _CoachCard(this.coach);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: coach.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coach.expertise,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            coach.tagline,
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.iconOrange,
              ),
              const SizedBox(width: 4),
              Text(
                coach.rating.toStringAsFixed(1),
                style: _tabular(
                  GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${coach.sessions} sessions',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              label: 'Book session',
              variant: _PillVariant.tint,
              onPressed: () => _demoAction(context),
            ),
          ),
        ],
      ),
    );
  }
}
