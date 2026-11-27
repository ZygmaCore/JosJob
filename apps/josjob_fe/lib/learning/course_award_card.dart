import 'package:flutter/material.dart';
import '../services/course_awards_api.dart';
import '../services/session.dart';
import '../services/workflow_client.dart';
import '../dashboard/screens/curriculum_vitae_view.dart'
    show reviewCvForCertificate;
import '../theme/app_theme.dart';

class CourseAwardCard extends StatefulWidget {
  final Map<String, dynamic> award;
  final CourseAwardsApi? api;
  final WorkflowAuthorize? authorize;
  final bool primaryAction;
  const CourseAwardCard({
    super.key,
    required this.award,
    this.api,
    this.authorize,
    this.primaryAction = true,
  });
  @override
  State<CourseAwardCard> createState() => _CourseAwardCardState();
}

class _CourseAwardCardState extends State<CourseAwardCard> {
  late Map<String, dynamic> _award = widget.award;
  late final _api = widget.api ?? CourseAwardsApi();
  bool _busy = false;
  String? _error;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);
  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CourseAwardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.award['id'] != oldWidget.award['id'] ||
        widget.award['name_locked'] == true) {
      _award = widget.award;
    }
  }

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      while (mounted) {
        final preview = await _auth(
          (token) => _api.preview(token, _award['id'] as String),
        );
        if (!mounted) return;
        if (preview['name_locked'] == true) {
          setState(() => _award = preview);
          return;
        }
        var checked = false;
        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: const Text('Confirm certificate name'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview['title'] as String,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Is this the correct name for your certificate? It comes from your saved CV.',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      preview['cv_name'] as String? ?? 'Add your CV name first',
                      key: const ValueKey('certificate-name-preview'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Once issued, the name on this certificate cannot be changed. Your CV can still be edited for future certificates.',
                    ),
                    TextButton(
                      key: const ValueKey('edit-cv-before-certificate'),
                      onPressed: () => Navigator.pop(dialogContext, 'edit'),
                      child: const Text('Correct name in CV'),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const ValueKey('confirm-certificate-cv'),
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      onChanged: (value) =>
                          update(() => checked = value == true),
                      title: const Text(
                        'This is the correct name for this certificate.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  key: const ValueKey('issue-locked-certificate'),
                  onPressed:
                      checked &&
                          (preview['cv_name'] as String? ?? '').trim().length >=
                              2
                      ? () => Navigator.pop(dialogContext, 'confirm')
                      : null,
                  child: const Text('Issue certificate'),
                ),
              ],
            ),
          ),
        );
        if (!mounted || action == null) return;
        if (action == 'edit') {
          await reviewCvForCertificate(context, authorize: _auth);
          continue;
        }
        final issued = await _auth(
          (token) => _api.confirm(
            token,
            _award['id'] as String,
            preview['cv_name'] as String,
          ),
        );
        if (mounted) setState(() => _award = issued);
        return;
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issued = _award['name_locked'] == true;
    return Card(
      key: ValueKey('course-award-${_award['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    issued ? 'Certificate issued' : 'Certificate pending',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (issued) ...[
              const Text('Awarded to'),
              const SizedBox(height: 6),
              Text(
                _award['recipient_name'] as String,
                key: const ValueKey('locked-certificate-name'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
            ],
            Text(
              _award['title'] as String,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in _award['skill_tags'] as List? ?? [])
                  Chip(
                    avatar: const Icon(Icons.school_outlined, size: 16),
                    label: Text(skill as String),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              issued
                  ? 'Issued by JosJob / ${_award['issued_on']}'
                  : 'These skill tags have been added to your profile and job matching.',
            ),
            if (issued) ...[
              const SizedBox(height: 8),
              SelectableText(_award['credential_id'] as String? ?? ''),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Recipient name locked for this certificate.'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              if (widget.primaryAction)
                FilledButton.icon(
                  key: const ValueKey('claim-course-certificate'),
                  onPressed: _busy ? null : _claim,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(_busy ? 'Loading...' : 'Get certificate'),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('claim-course-certificate'),
                  onPressed: _busy ? null : _claim,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(_busy ? 'Loading...' : 'Get certificate'),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  key: const ValueKey('certificate-claim-error'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
