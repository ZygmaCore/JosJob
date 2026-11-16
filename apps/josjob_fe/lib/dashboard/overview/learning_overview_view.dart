import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/courses_api.dart' show formatPrice;
import '../../services/learning_overview_api.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';

typedef LearningAuthorize =
    Future<T> Function<T>(Future<T> Function(String) call);

/// Live Learn overview. Counts describe enrollments, not unrecorded lesson progress.
class LearningOverviewView extends StatefulWidget {
  final bool organization;
  final String? firstName;
  final VoidCallback? onBrowseCourses;
  final VoidCallback? onUploadVideo;
  final Future<void> Function(LearningCourse)? onOpenCourse;
  final LearningOverviewApi? api;
  final LearningAuthorize? authorize;
  const LearningOverviewView({
    super.key,
    this.organization = false,
    this.firstName,
    this.onBrowseCourses,
    this.onUploadVideo,
    this.onOpenCourse,
    this.api,
    this.authorize,
  });

  @override
  State<LearningOverviewView> createState() => _LearningOverviewViewState();
}

class _LearningOverviewViewState extends State<LearningOverviewView> {
  late LearningOverviewApi _api;
  LearningOverview? _data;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? LearningOverviewApi();
    _load();
  }

  @override
  void didUpdateWidget(covariant LearningOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      if (oldWidget.api == null) _api.close();
      _api = widget.api ?? LearningOverviewApi();
    }
    if (oldWidget.organization != widget.organization ||
        oldWidget.api != widget.api ||
        oldWidget.authorize != widget.authorize) {
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final authorize = widget.authorize ?? Session.instance.runAuthed;
      final result = await authorize(
        (token) => _api.fetch(token, organization: widget.organization),
      );
      if (mounted && request == _request) setState(() => _data = result);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(LearningCourse course) async {
    if (widget.onOpenCourse == null) return;
    await widget.onOpenCourse!(course);
    if (mounted) await _load();
  }

  TextStyle _style(
    double size, {
    bool bold = false,
    Color color = AppColors.navy,
  }) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    color: color,
  );

  Widget _card(Widget child, {Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _empty(String message, {String? action, VoidCallback? onAction}) =>
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: _style(13, color: AppColors.body)),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      );

  Widget _section(
    String title,
    Widget child, {
    required String id,
    String? description,
  }) => Column(
    key: ValueKey(id),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: _style(18, bold: true)),
      if (description != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description, style: _style(12, color: AppColors.body)),
        ),
      const SizedBox(height: 14),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final name = widget.firstName?.trim() ?? '';
    return Column(
      key: const ValueKey('learning-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Welcome back!' : 'Welcome back, $name!',
                    style: _style(26, bold: true),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.organization
                        ? 'Your organization’s learning snapshot'
                        : 'Your learning, at a glance',
                    style: _style(14, color: AppColors.body),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('refresh-learning-overview'),
              tooltip: 'Refresh overview',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading)
          _card(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  key: ValueKey('learning-overview-loading'),
                ),
              ),
            ),
          )
        else if (_error != null)
          _card(
            Column(
              key: const ValueKey('learning-overview-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Couldn’t load your overview',
                  style: _style(17, bold: true),
                ),
                const SizedBox(height: 8),
                Text(_error!, style: _style(13, color: AppColors.body)),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('retry-learning-overview'),
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          )
        else if (_data != null)
          ..._content(_data!),
      ],
    );
  }

  List<Widget> _content(LearningOverview data) {
    final organization = data.scope == 'organization';
    final stats = [
      (
        organization ? 'members' : 'active_enrollments',
        organization ? 'Team members' : 'Active enrollments',
        Icons.groups_outlined,
      ),
      (
        'completed_enrollments',
        'Completed enrollments',
        Icons.task_alt_outlined,
      ),
      (
        'available_courses',
        organization ? 'Training courses' : 'Available courses',
        Icons.menu_book_outlined,
      ),
      ('upcoming_sessions', 'Upcoming sessions', Icons.event_outlined),
    ];
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 800
              ? 4
              : constraints.maxWidth >= 420
              ? 2
              : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (key, label, icon) in stats)
                SizedBox(
                  width: (constraints.maxWidth - 16 * (columns - 1)) / columns,
                  child: _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppColors.brandBlue),
                        const SizedBox(height: 16),
                        Text(
                          '${data.stats[key]!}',
                          key: ValueKey('learning-stat-$key'),
                          style: _style(28, bold: true),
                        ),
                        const SizedBox(height: 4),
                        Text(label, style: _style(12, color: AppColors.body)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 30),
      if (organization)
        _section(
          'Team learning',
          _completionList(data.members, empty: 'No active team members yet.'),
          id: 'learning-team',
          description:
              'Completed class enrollments for active members. Showing up to 6 learners.',
        )
      else
        _section(
          'Continue learning',
          data.enrollments.isEmpty
              ? _empty(
                  'You haven’t enrolled in a class yet. Explore the catalog to get started.',
                  action: 'Browse courses',
                  onAction: widget.onBrowseCourses,
                )
              : Column(
                  children: [
                    for (final enrollment in data.enrollments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _courseCard(
                          enrollment.course,
                          subtitle: enrollment.classTitle.isEmpty
                              ? 'Active enrollment'
                              : '${enrollment.classTitle} · Enrolled',
                          id: 'learning-enrollment-${enrollment.id}',
                        ),
                      ),
                  ],
                ),
          id: 'learning-enrollments',
          description: 'Your most recent active class enrollments.',
        ),
      const SizedBox(height: 30),
      _section(
        organization ? 'Training offerings' : 'Courses to explore',
        data.courses.isEmpty
            ? _empty(
                organization
                    ? 'No active courses have been shared with your organization.'
                    : 'No additional courses are available right now.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 620 ? 2 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final course in data.courses)
                        SizedBox(
                          width:
                              (constraints.maxWidth - 16 * (columns - 1)) /
                              columns,
                          child: _courseCard(
                            course,
                            id: 'learning-course-${course.id}',
                          ),
                        ),
                    ],
                  );
                },
              ),
        id: 'learning-courses',
        description: organization
            ? 'Active courses shared with organizations you can manage.'
            : 'Available catalog courses you haven’t enrolled in, ordered by title.',
      ),
      if (organization && widget.onUploadVideo != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onUploadVideo,
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Upload video'),
          ),
        ),
      const SizedBox(height: 30),
      _section(
        'Upcoming sessions',
        data.sessions.isEmpty
            ? _empty(
                organization
                    ? 'No upcoming class sessions are scheduled.'
                    : 'No upcoming sessions for your active enrollments.',
              )
            : _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final session in data.sessions)
                      Padding(
                        key: ValueKey(
                          'learning-session-${session.classId}-${session.date}-${session.start}',
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              color: AppColors.brandBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.courseTitle,
                                    style: _style(14, bold: true),
                                  ),
                                  Text(
                                    session.scheduleLabel,
                                    style: _style(13, color: AppColors.body),
                                  ),
                                  if (session.instructor != null)
                                    Text(
                                      session.instructor!,
                                      style: _style(12, color: AppColors.body),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
        id: 'learning-sessions',
        description:
            'Dates and times follow each class schedule. Showing up to 6 sessions.',
      ),
      if (organization) ...[
        const SizedBox(height: 30),
        _section(
          'Course completion',
          _completionList(
            data.completion,
            empty: 'No training enrollments to summarize yet.',
          ),
          id: 'learning-completion',
          description:
              'Completed enrollments out of all enrollments in each course.',
        ),
      ],
      const SizedBox(height: 24),
      Text(
        'Study hours, lesson progress and certificates aren’t available yet.',
        key: const ValueKey('learning-unavailable-metrics'),
        style: _style(12, color: AppColors.body),
      ),
    ];
  }

  Widget _courseCard(
    LearningCourse course, {
    String? subtitle,
    required String id,
  }) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.section ?? 'Course',
          style: _style(11, bold: true, color: AppColors.brandBlue),
        ),
        const SizedBox(height: 8),
        Text(course.title, style: _style(16, bold: true)),
        const SizedBox(height: 8),
        Text(
          subtitle ?? course.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _style(13, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle != null
                    ? 'Enrolled'
                    : (course.priceCents == null || course.priceCents! <= 0)
                    ? 'Free'
                    : formatPrice(course.priceCents!, course.currency),
                style: _style(12, bold: true, color: AppColors.brandBlue),
              ),
            ),
            if (widget.onOpenCourse != null)
              TextButton(
                onPressed: () => _open(course),
                child: const Text('View course'),
              ),
          ],
        ),
      ],
    ),
    key: ValueKey(id),
  );

  Widget _completionList(
    List<LearningCompletion> records, {
    required String empty,
  }) => records.isEmpty
      ? _empty(empty)
      : _card(
          Column(
            children: [
              for (final record in records)
                Padding(
                  key: ValueKey('learning-completion-${record.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.title, style: _style(14, bold: true)),
                      const SizedBox(height: 6),
                      Text(
                        record.enrolled == 0
                            ? 'No enrollments'
                            : '${record.completed} of ${record.enrolled} enrollments completed',
                        style: _style(12, color: AppColors.body),
                      ),
                      if (record.enrolled > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: record.fraction,
                            minHeight: 6,
                            backgroundColor: AppColors.tintBlue,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
}
