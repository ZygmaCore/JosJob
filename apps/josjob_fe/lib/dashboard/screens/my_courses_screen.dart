part of '../dashboard_page.dart';

// =========================================================================
// "My Courses" destination (learner Learn view): the courses you're enrolled
// in, fetched live from GET /api/me/enrollments. Distinct from "Courses",
// which browses the full catalog.
// =========================================================================
class _MyCoursesScreen extends StatefulWidget {
  const _MyCoursesScreen();

  @override
  State<_MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<_MyCoursesScreen> {
  final CoursesApi _api = CoursesApi();

  bool _loading = true;
  String? _error;
  List<EnrolledCourse> _courses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Session.instance.runAuthed(
        (t) => _api.listEnrollments(t),
      );
      if (!mounted) return;
      setState(() {
        _courses = list;
        _loading = false;
      });
    } on CourseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'My courses',
          actionLabel: 'Browse catalog',
          onAction: () => _explore(context),
        ),
        const SizedBox(height: 6),
        Text(
          _subtitle(),
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _body(),
      ],
    );
  }

  String _subtitle() {
    if (_loading) return 'Loading your courses…';
    if (_error != null) return '';
    return _courses.isEmpty
        ? "You haven't enrolled in any courses yet."
        : '${_courses.length} enrolled';
  }

  Widget _body() {
    if (_loading) {
      return const _DashCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
              ),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return _DashCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your courses",
            subtitle: _error!,
            actionLabel: 'Try again',
            onAction: _load,
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return _DashCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: _EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No courses yet',
            subtitle: 'Browse the catalog and enroll to start learning.',
            actionLabel: 'Browse courses',
            onAction: () => _explore(context),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final c in _courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EnrolledCourseCard(c),
          ),
      ],
    );
  }
}

class _EnrolledCourseCard extends StatelessWidget {
  final EnrolledCourse course;
  const _EnrolledCourseCard(this.course);

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (course.classTitle.isNotEmpty) course.classTitle,
      course.scheduleLabel,
    ].where((s) => s.isNotEmpty).join(' · ');

    return _DashCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.tintBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: AppColors.iconBlue,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppColors.body,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _enrolPill(course.completed),
        ],
      ),
    );
  }

  Widget _enrolPill(bool completed) {
    final (label, bg, fg) = completed
        ? ('Completed', AppColors.tintBlue, AppColors.brandBlue)
        : ('Enrolled', AppColors.tintGreen, AppColors.iconGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.workspace_premium_outlined : Icons.check_circle,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
