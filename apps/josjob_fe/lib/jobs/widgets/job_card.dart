part of '../jobs_page.dart';

/// API-backed opportunity card using the catalog and dashboard design tokens.
class _JobCard extends StatelessWidget {
  final JobListing job;
  final VoidCallback onTap;
  const _JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [_cardShadow],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: AppColors.tintBlue.withValues(alpha: 0.4),
          focusColor: AppColors.focus,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: _logoGradient(job.company.length),
                        borderRadius: BorderRadius.circular(14),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.body,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(job.employmentType),
                    _tag(job.workMode),
                    if (job.synthetic) const _JobBadge('Synthetic demo'),
                    if (job.status != 'active') _JobBadge(job.status),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.7,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 16),
                _meta(Icons.place_outlined, job.location),
                if (job.industry.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _meta(Icons.business_center_outlined, job.industry),
                ],
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in job.requirements.take(3))
                        _tag(skill, skill: true),
                      if (job.requirements.length > 3)
                        _tag(
                          '+${job.requirements.length - 3} more',
                          skill: true,
                        ),
                    ],
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        job.salaryLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Tooltip(
                      message: 'View role details',
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, {bool skill = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: skill ? AppColors.bg : AppColors.tintBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: skill ? AppColors.body : AppColors.brandBlue,
      ),
    ),
  );

  Widget _meta(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.iconBlue),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
        ),
      ),
    ],
  );
}
