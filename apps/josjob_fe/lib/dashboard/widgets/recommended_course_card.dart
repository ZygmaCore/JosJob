part of '../dashboard_page.dart';

// =========================================================================
// Recommended course card: gradient thumbnail + category tag, title, and a
// meta row (level chip · duration · rating). Whole card is tappable.
// =========================================================================
class _RecommendedCourseCard extends StatelessWidget {
  final _DashCourse course;
  const _RecommendedCourseCard(this.course);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${course.title}, ${course.category}, ${course.level}, '
          '${course.duration}, rated ${course.rating}',
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => _demoAction(context),
          focusColor: AppColors.focus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 88,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.topLeft,
                decoration: BoxDecoration(
                  gradient: _thumbGradient(course.seed),
                ),
                child: _OnThumbTag(course.category),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _LevelChip(course.level),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: AppColors.body,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.duration,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.body,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          course.rating.toStringAsFixed(1),
                          style: _tabular(
                            GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  const _LevelChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.iconBlue,
        ),
      ),
    );
  }
}
