import 'package:flutter/material.dart';
import '../services/study_api.dart';
import '../services/session.dart';
import '../services/workflow_client.dart';
import '../theme/app_theme.dart';
import 'course_award_card.dart';

class CourseStudyPage extends StatefulWidget {
  final String courseId;
  final StudyApi? api;
  final WorkflowAuthorize? authorize;
  const CourseStudyPage({
    super.key,
    required this.courseId,
    this.api,
    this.authorize,
  });
  @override
  State<CourseStudyPage> createState() => _CourseStudyPageState();
}

class _CourseStudyPageState extends State<CourseStudyPage> {
  late final _api = widget.api ?? StudyApi();
  Map<String, dynamic>? _course;
  String? _selected, _error, _feedback;
  bool _busy = false;
  final Map<String, int> _answers = {};
  final _contentScroll = ScrollController(keepScrollOffset: false);
  Future<T> _auth<T>(Future<T> Function(String) fn) =>
      (widget.authorize ?? Session.instance.runAuthed)(fn);
  List<Map<String, dynamic>> get _lessons =>
      (_course?['lessons'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contentScroll.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() =>
      _run(() => _auth((t) => _api.get(t, widget.courseId)));
  Future<void> _run(
    Future<Map<String, dynamic>> Function() call, {
    bool assessment = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await call();
      if (!mounted) return;
      setState(() {
        _course = result;
        final feedback = result['assessment'] as Map?;
        if (assessment && feedback?['passed'] == false) {
          _feedback =
              'Score: ${feedback?['score']}%. You need 80% to pass. Review the material and try again.';
        } else {
          _feedback = assessment
              ? (feedback?['score'] == null
                    ? 'Lesson completed. Your progress is saved.'
                    : 'Passed: ${feedback?['score']}%. Your progress is saved.')
              : null;
          _selected =
              result['resume_lesson_id'] as String? ??
              _lessons.lastOrNull?['id'] as String?;
          _answers.clear();
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _contentScroll.hasClients) _contentScroll.jumpTo(0);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _syllabus({bool closeOnSelect = false}) {
    final lessons = _lessons;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Course curriculum',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (closeOnSelect)
              IconButton(
                tooltip: 'Close curriculum',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final lesson in lessons) ...[
          if (lesson == lessons.first ||
              lesson['module_title'] !=
                  lessons[lessons.indexWhere((l) => l['id'] == lesson['id']) -
                      1]['module_title'])
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                lesson['module_title'] as String,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ListTile(
            key: ValueKey('study-lesson-${lesson['id']}'),
            selected: _selected == lesson['id'],
            selectedTileColor: AppColors.tintBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(
              lesson['completed'] == true
                  ? Icons.check_circle
                  : lesson['unlocked'] == true
                  ? Icons.menu_book_outlined
                  : Icons.lock_outline,
              color: lesson['completed'] == true
                  ? Colors.green.shade700
                  : AppColors.brandBlue,
            ),
            title: Text(lesson['title'] as String),
            subtitle: Text(
              lesson['kind'] == 'quiz'
                  ? 'Quiz · pass score 80%'
                  : 'Reading & practice',
            ),
            onTap: _busy || lesson['unlocked'] != true
                ? null
                : () {
                    setState(() {
                      _selected = lesson['id'] as String;
                      _answers.clear();
                      _feedback = null;
                    });
                    if (closeOnSelect) Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _contentScroll.hasClients) {
                        _contentScroll.jumpTo(0);
                      }
                    });
                  },
          ),
        ],
      ],
    );
  }

  Widget _content() {
    final course = _course!;
    final lesson = _lessons.where((l) => l['id'] == _selected).firstOrNull;
    return ListView(
      key: ValueKey('study-content-$_selected'),
      controller: _contentScroll,
      padding: const EdgeInsets.all(24),
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
        ],
        if (_feedback != null) ...[
          Text(_feedback!, key: const ValueKey('study-feedback')),
          const SizedBox(height: 16),
        ],
        if (course['progress'] == 100) ...[
          if (course['award'] is Map)
            CourseAwardCard(
              award: Map<String, dynamic>.from(course['award'] as Map),
              authorize: widget.authorize,
            ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Course completed! You have finished the lessons and passed the knowledge check.',
                key: ValueKey('study-course-complete'),
              ),
            ),
          ),
        ],
        if (course['enrolled'] != true) ...[
          Text(
            'Learn at your own pace',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Read the lessons, complete the guided practice and pass the knowledge check. Your progress is saved to your account, so you can continue on another visit.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('start-course-study'),
            onPressed: _busy
                ? null
                : () =>
                      _run(() => _auth((t) => _api.enroll(t, widget.courseId))),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start learning'),
          ),
        ] else if (lesson != null) ...[
          Text(
            lesson['module_title'] as String,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            lesson['title'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          SelectableText(
            lesson['body'] as String? ?? '',
            style: const TextStyle(fontSize: 16, height: 1.8),
          ),
          if (lesson['kind'] == 'quiz') ...[
            for (final raw in lesson['questions'] as List) ...[
              const SizedBox(height: 24),
              Text(
                raw['prompt'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RadioGroup<int>(
                groupValue: _answers[raw['id']],
                onChanged: (v) {
                  if (v != null && !_busy) {
                    setState(() => _answers[raw['id'] as String] = v);
                  }
                },
                child: Column(
                  children: [
                    for (var i = 0; i < (raw['options'] as List).length; i++)
                      RadioListTile<int>(
                        value: i,
                        title: Text(raw['options'][i] as String),
                      ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 28),
          if (lesson['completed'] != true)
            FilledButton.icon(
              key: const ValueKey('complete-study-lesson'),
              onPressed:
                  _busy ||
                      (lesson['kind'] == 'quiz' &&
                          _answers.length !=
                              (lesson['questions'] as List).length)
                  ? null
                  : () => _run(
                      () => _auth(
                        (t) => _api.complete(
                          t,
                          widget.courseId,
                          lesson['id'] as String,
                          _answers,
                        ),
                      ),
                      assessment: true,
                    ),
              icon: Icon(
                lesson['kind'] == 'quiz'
                    ? Icons.fact_check_outlined
                    : Icons.check,
              ),
              label: Text(
                lesson['kind'] == 'quiz'
                    ? 'Submit answers'
                    : 'Mark as complete & continue',
              ),
            ),
        ] else
          const Text('No published lessons are available yet.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to learning',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.pop(context);
          } else {
            Navigator.of(context).pushReplacementNamed('/dashboard?view=learn');
          }
        },
      ),
      title: Text(_course?['title'] as String? ?? 'Course learning'),
    ),
    body: _course == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_course!['progress'] as num) / 100,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${_course!['completed_count']}/${_course!['lesson_count']} lessons · ${_course!['progress']}%',
                      key: const ValueKey('study-progress'),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, size) => size.maxWidth >= 900
                      ? Row(
                          children: [
                            SizedBox(width: 310, child: _syllabus()),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 850,
                                  ),
                                  child: _content(),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('open-mobile-curriculum'),
                                  onPressed: () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    showDragHandle: true,
                                    builder: (_) => SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          .7,
                                      child: _syllabus(closeOnSelect: true),
                                    ),
                                  ),
                                  icon: const Icon(Icons.format_list_bulleted),
                                  label: const Text('Course curriculum'),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(child: _content()),
                          ],
                        ),
                ),
              ),
            ],
          ),
  );
}
