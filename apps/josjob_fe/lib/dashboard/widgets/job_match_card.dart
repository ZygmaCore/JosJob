part of '../dashboard_page.dart';

// =========================================================================
// A matched-role card for the Jobs overview: company logo tile, title, a
// match-score badge, location/type meta and a "View role" action.
// =========================================================================
class _JobMatchCard extends StatelessWidget {
  final _JobMatch job;
  const _JobMatchCard(this.job);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _thumbGradient(job.seed),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _initials(job.company),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MatchBadge(job.matchPct),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _JobMeta(Icons.place_outlined, job.location),
              _JobMeta(Icons.schedule_outlined, job.type),
            ],
          ),
          const SizedBox(height: 16),
          _PillButton(
            label: 'View role',
            icon: Icons.arrow_forward,
            variant: _PillVariant.tint,
            onPressed: () => _browseJobs(context),
          ),
        ],
      ),
    );
  }
}

// Green match-score pill, e.g. "96% match".
class _MatchBadge extends StatelessWidget {
  final int pct;
  const _MatchBadge(this.pct);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pct% match',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.iconGreen,
        ),
      ),
    );
  }
}

// Small icon + label meta row (location, employment type).
class _JobMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _JobMeta(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.body),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
        ),
      ],
    );
  }
}
