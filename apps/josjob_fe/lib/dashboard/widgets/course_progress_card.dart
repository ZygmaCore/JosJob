part of '../dashboard_page.dart';

// =========================================================================
// "Continue learning" card: gradient thumbnail band with a category tag,
// title, module position, a progress bar and a Resume action.
// =========================================================================
class _CourseProgressCard extends StatelessWidget {
  final _DashCourse course;
  const _CourseProgressCard(this.course);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 76,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.topLeft,
            decoration: BoxDecoration(gradient: _thumbGradient(course.seed)),
            child: _OnThumbTag(course.category),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Module ${course.moduleCurrent} of ${course.moduleTotal}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 14),
                _ProgressBar(value: course.progress),
                const SizedBox(height: 16),
                _PillButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _resumeCourse(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Category tag rendered on top of a gradient thumbnail (translucent white).
class _OnThumbTag extends StatelessWidget {
  final String label;
  const _OnThumbTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
