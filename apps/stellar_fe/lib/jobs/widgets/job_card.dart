part of '../jobs_page.dart';

// =========================================================================
// A tappable role card on the board: company logo, title, match badge, a
// short summary and meta (type / salary / location).
// =========================================================================
class _JobCard extends StatelessWidget {
  final _Job job;
  final VoidCallback onTap;
  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [_cardShadow],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _logoGradient(job.seed),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      _initials(job.company),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${job.company} · ${job.location}',
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
              Text(
                job.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _meta(Icons.schedule_outlined, job.type),
                  _meta(Icons.payments_outlined, job.salary),
                  _meta(Icons.place_outlined, job.location),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
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
