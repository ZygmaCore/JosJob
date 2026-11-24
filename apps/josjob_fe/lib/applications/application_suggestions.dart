import 'package:flutter/material.dart';
import '../explore/explore_page.dart' show showCatalogCourse;
import '../services/applications_api.dart';
import '../services/workflow_client.dart';
import '../theme/app_theme.dart';

/// Advisory learning suggestions never prevent the candidate from applying.
class ApplicationSuggestionsCard extends StatefulWidget {
  final String jobId;
  final ApplicationsApi api;
  final WorkflowAuthorize authorize;
  const ApplicationSuggestionsCard({
    super.key,
    required this.jobId,
    required this.api,
    required this.authorize,
  });

  @override
  State<ApplicationSuggestionsCard> createState() =>
      _ApplicationSuggestionsCardState();
}

class _ApplicationSuggestionsCardState
    extends State<ApplicationSuggestionsCard> {
  ApplicationSuggestions? _suggestions;
  bool _loading = true;
  bool _failed = false;
  bool _showAllCourses = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.authorize(
        (token) => widget.api.suggestions(token, widget.jobId),
      );
      if (mounted) setState(() => _suggestions = result);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _suggestions;
    final theme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('application-suggestions'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: AppColors.brandBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Build skills for this role',
                  style: theme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) ...[
            const LinearProgressIndicator(
              key: ValueKey('application-suggestions-loading'),
            ),
            const SizedBox(height: 8),
            const Text('Checking your saved CV skills...'),
          ] else if (_failed) ...[
            const Text(
              'Learning suggestions are unavailable. You can still submit your application.',
              key: ValueKey('application-suggestions-error'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('retry-application-suggestions'),
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ),
          ] else if (data != null) ...[
            if (data.status == 'cv_required')
              const Text(
                'Add skills to your CV profile or analyze your CV from Jobs to get learning suggestions. You can still apply now.',
                key: ValueKey('application-suggestions-cv-required'),
              )
            else if (data.status == 'no_requirements')
              const Text(
                'This role has no specific skill requirements to compare.',
                key: ValueKey('application-suggestions-no-requirements'),
              )
            else ...[
              Text(
                data.source == 'analyzed_cv'
                    ? 'Compared with your last analyzed CV.'
                    : 'Compared with the skills in your saved CV profile.',
                style: theme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (data.status == 'matched')
                const Text(
                  'All listed skill requirements were found. You are ready to apply.',
                  key: ValueKey('application-suggestions-matched'),
                )
              else ...[
                const Text(
                  'These required skills were not found in your CV:',
                  key: ValueKey('application-skill-gap'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final skill in data.missingSkills)
                      Chip(label: Text(skill)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('You can apply now and learn at your own pace.'),
                for (final suggestion
                    in _showAllCourses
                        ? data.courses
                        : data.courses.take(2)) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            suggestion.course.title,
                            style: theme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Skills covered: ${suggestion.matchedSkills.join(', ')}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${suggestion.course.isFree ? 'Free' : suggestion.course.priceLabel} · '
                            '${suggestion.course.classCount == 0 ? 'No classes scheduled yet' : '${suggestion.course.classCount} ${suggestion.course.classCount == 1 ? 'class' : 'classes'}'}',
                            style: theme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              key: ValueKey(
                                'suggested-course-${suggestion.course.id}',
                              ),
                              onPressed: () => showCatalogCourse(
                                context,
                                suggestion.course,
                                returnLabel: 'Back to application',
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: const Text('View course & classes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!_showAllCourses && data.courses.length > 2)
                  TextButton(
                    onPressed: () => setState(() => _showAllCourses = true),
                    child: Text(
                      'Show all ${data.courses.length} suggested courses',
                    ),
                  ),
                if (data.uncoveredSkills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No matching course is available yet for: ${data.uncoveredSkills.join(', ')}.',
                    key: const ValueKey('application-suggestions-uncovered'),
                    style: theme.bodySmall,
                  ),
                ],
              ],
            ],
          ],
        ],
      ),
    );
  }
}
