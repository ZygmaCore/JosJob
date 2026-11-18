import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../chat/chat_page.dart';
import '../services/applications_api.dart';
import '../services/jobs_api.dart';
import '../services/open_link.dart';
import '../services/session.dart';
import '../services/workflow_client.dart';
import '../shared/app_form_field.dart';
import '../theme/app_theme.dart';

TextStyle _style(
  double size, {
  bool bold = false,
  Color color = AppColors.ink,
}) => GoogleFonts.poppins(
  fontSize: size,
  color: color,
  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
);
String _date(DateTime value) {
  final d = value.toLocal();
  return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Widget _card(Widget child, {Key? key}) => SizedBox(
  width: double.infinity,
  child: Material(
    key: key,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);
Widget _stage(String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: status == 'rejected' || status == 'withdrawn'
        ? AppColors.paper2
        : AppColors.tintBlue,
    borderRadius: BorderRadius.circular(99),
  ),
  child: Text(
    stageLabel(status),
    style: _style(12, color: AppColors.navy, bold: true),
  ),
);

class ApplicationsPage extends StatelessWidget {
  final bool hiring;
  final String? jobId;
  const ApplicationsPage({super.key, this.hiring = false, this.jobId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: Text(hiring ? 'Hiring' : 'Applications')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ApplicationsView(hiring: hiring, jobId: jobId),
        ),
      ),
    ),
  );
}

class ApplicationsView extends StatefulWidget {
  final ApplicationsApi? api;
  final WorkflowAuthorize? authorize;
  final bool hiring;
  final String? jobId;
  const ApplicationsView({
    super.key,
    this.api,
    this.authorize,
    this.hiring = false,
    this.jobId,
  });
  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  late final ApplicationsApi _api = widget.api ?? ApplicationsApi();
  late String _scope = widget.hiring ? 'hiring' : 'mine';
  String _status = '';
  int _page = 1, _generation = 0;
  ApplicationResults? _data;
  bool _loading = true;
  String? _error;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _auth(
        (t) => _api.list(
          t,
          scope: _scope,
          status: _status,
          page: _page,
          jobId: widget.jobId,
        ),
      );
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _data = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(JobApplication application) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationDetailPage(
          applicationId: application.id,
          api: _api,
          authorize: widget.authorize,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('applications-view'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _scope == 'hiring' ? 'Hiring workspace' : 'Your applications',
                style: _style(24, bold: true, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              Text(
                _scope == 'hiring'
                    ? 'Review candidates and keep every next step clear.'
                    : 'Follow your next opportunity, one step at a time.',
                style: _style(13, color: AppColors.body),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const ValueKey('refresh-applications'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
      if (_data?.canHire == true || widget.hiring) ...[
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          children: [
            for (final scope in ['mine', 'hiring'])
              ChoiceChip(
                key: ValueKey('application-scope-$scope'),
                label: Text(scope == 'mine' ? 'My applications' : 'Hiring'),
                selected: _scope == scope,
                onSelected: _loading
                    ? null
                    : (_) {
                        _scope = scope;
                        _status = '';
                        _page = 1;
                        _load();
                      },
              ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final s in hiringStages)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${_data?.counts[s] ?? 0}  ${stageLabel(s)}',
                style: _style(13, bold: true, color: AppColors.navy),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in ['', ...hiringStages, 'rejected', 'withdrawn'])
            FilterChip(
              key: ValueKey('application-filter-$s'),
              label: Text(stageLabel(s)),
              selected: _status == s,
              onSelected: _loading
                  ? null
                  : (_) {
                      _status = s;
                      _page = 1;
                      _load();
                    },
            ),
        ],
      ),
      const SizedBox(height: 18),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _card(
          Column(
            children: [
              Text(_error!, key: const ValueKey('applications-error')),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        )
      else if (_data!.applications.isEmpty)
        _card(
          Column(
            key: const ValueKey('applications-empty'),
            children: [
              const Icon(
                Icons.work_outline,
                size: 40,
                color: AppColors.brandBlue,
              ),
              const SizedBox(height: 12),
              Text(
                _scope == 'hiring'
                    ? 'No applications to review'
                    : 'No applications here yet',
                style: _style(18, bold: true),
              ),
              const SizedBox(height: 8),
              Text(
                _scope == 'hiring'
                    ? 'Applications to your organization’s listings will appear here.'
                    : 'Apply to an active role to start tracking your progress.',
                style: _style(13, color: AppColors.body),
              ),
            ],
          ),
        )
      else ...[
        for (final application in _data!.applications)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              InkWell(
                key: ValueKey('application-${application.id}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => _open(application),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.tintBlue,
                      child: Icon(
                        Icons.work_outline,
                        color: AppColors.brandBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.jobTitle,
                            style: _style(
                              15,
                              bold: true,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            _scope == 'hiring'
                                ? '${application.candidateName} · ${application.company}'
                                : application.company,
                            style: _style(13, color: AppColors.body),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Applied ${_date(application.appliedAt)}',
                            style: _style(11, color: AppColors.body),
                          ),
                          const SizedBox(height: 8),
                          _stage(application.status),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.brandBlue),
                  ],
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Page ${_data!.page} of ${_data!.totalPages}',
              style: _style(12, color: AppColors.body),
            ),
            IconButton(
              key: const ValueKey('applications-previous'),
              tooltip: 'Previous page',
              onPressed: _page <= 1
                  ? null
                  : () {
                      _page--;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const ValueKey('applications-next'),
              tooltip: 'Next page',
              onPressed: _page >= _data!.totalPages
                  ? null
                  : () {
                      _page++;
                      _load();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ],
  );
}

class ApplicationDetailPage extends StatefulWidget {
  final String applicationId;
  final ApplicationsApi? api;
  final WorkflowAuthorize? authorize;
  const ApplicationDetailPage({
    super.key,
    required this.applicationId,
    this.api,
    this.authorize,
  });
  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  late final ApplicationsApi _api = widget.api ?? ApplicationsApi();
  JobApplication? _data;
  String? _error;
  bool _working = false;
  int _generation = 0;
  Timer? _timer;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_working) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final data = await _auth((t) => _api.get(t, widget.applicationId));
      if (mounted && generation == _generation) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          if (e is WorkflowException && e.statusCode == 404) _data = null;
        });
      }
    }
  }

  Future<void> _change(String target) async {
    final note = TextEditingController();
    DateTime? interview;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(
            target == 'withdrawn'
                ? 'Withdraw application?'
                : 'Move to ${stageLabel(target)}?',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    target == 'withdrawn'
                        ? 'This ends your application and makes its chat read-only.'
                        : 'The applicant will see this stage change and your note.',
                    style: _style(13, color: AppColors.body),
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    label: 'Note for both participants (optional)',
                    controller: note,
                    maxLines: 3,
                    maxLength: 2000,
                  ),
                  if (target == 'interview') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('schedule-interview'),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        interview == null
                            ? 'Add interview time (optional)'
                            : _date(interview!),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: c,
                          builder: appFormDialog,
                          initialDate: now.add(const Duration(days: 1)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (date == null || !c.mounted) return;
                        final time = await showTimePicker(
                          context: c,
                          builder: appFormDialog,
                          initialTime: const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (time != null && c.mounted) {
                          update(
                            () => interview = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-application-stage'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    final text = note.text;
    note.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    _generation++;
    try {
      final data = await _auth(
        (t) =>
            _api.advance(t, _data!, target, note: text, interviewAt: interview),
      );
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text('Application details'),
      actions: [
        IconButton(
          tooltip: 'Refresh application',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _data == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(_error!),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  key: const ValueKey('application-detail'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          key: const ValueKey('application-detail-error'),
                          style: _style(13, color: AppColors.danger),
                        ),
                      ),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _data!.jobTitle,
                            style: _style(
                              24,
                              bold: true,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            _data!.company,
                            style: _style(15, color: AppColors.body),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _stage(_data!.status),
                              OutlinedButton.icon(
                                key: const ValueKey('application-chat'),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatPage(
                                      kind: 'application',
                                      contextId: _data!.id,
                                      title: 'Hiring conversation',
                                      authorize: widget.authorize,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(
                                  _data!.canChat
                                      ? 'Open chat'
                                      : 'View conversation',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final next in _data!.nextStatuses)
                                OutlinedButton(
                                  key: ValueKey('application-stage-$next'),
                                  onPressed: _working
                                      ? null
                                      : () => _change(next),
                                  child: Text(
                                    next == 'withdrawn'
                                        ? 'Withdraw application'
                                        : next == 'rejected'
                                        ? 'Reject application'
                                        : 'Move to ${stageLabel(next)}',
                                  ),
                                ),
                            ],
                          ),
                          if (_data!.interviewAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Interview: ${_date(_data!.interviewAt!)}',
                                style: _style(13, bold: true),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hiring progress',
                            style: _style(
                              18,
                              bold: true,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final stage in hiringStages)
                                Chip(
                                  avatar: Icon(
                                    _data!.history.any(
                                          (event) => event['status'] == stage,
                                        )
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: AppColors.brandBlue,
                                  ),
                                  label: Text(stageLabel(stage)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final event in _data!.history)
                            Padding(
                              key: ValueKey('application-event-${event['id']}'),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${stageLabel(event['status'] as String)} · ${_date(DateTime.parse(event['created_at'] as String))}',
                                    style: _style(13, bold: true),
                                  ),
                                  if ((event['note'] as String).isNotEmpty)
                                    SelectableText(
                                      event['note'] as String,
                                      style: _style(13, color: AppColors.body),
                                    ),
                                  if (event['scheduled_at'] != null)
                                    Text(
                                      'Interview time: ${_date(DateTime.parse(event['scheduled_at'] as String))}',
                                      style: _style(12, color: AppColors.body),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _card(
                      _SubmittedProfile(
                        profile: _data!.profile,
                        coverLetter: _data!.coverLetter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class _SubmittedProfile extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String coverLetter;
  final String heading;
  const _SubmittedProfile({
    required this.profile,
    this.coverLetter = '',
    this.heading = 'Submitted profile',
  });
  @override
  Widget build(BuildContext context) {
    final identity = profile['identity'] as Map? ?? {};
    final resume = profile['resume_document'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: _style(18, bold: true, color: AppColors.navy)),
        const SizedBox(height: 12),
        Text('${identity['full_name'] ?? ''}', style: _style(16, bold: true)),
        SelectableText(
          '${identity['email'] ?? ''}',
          style: _style(13, color: AppColors.body),
        ),
        for (final value in [
          identity['phone'],
          identity['location'],
          profile['headline'],
          profile['summary'],
        ])
          if (value is String && value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(value, style: _style(13)),
            ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final skill in profile['skills'] as List? ?? [])
              Chip(label: Text('$skill')),
          ],
        ),
        for (final section in ['experience', 'education']) ...[
          if ((profile[section] as List? ?? []).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(stageLabel(section), style: _style(14, bold: true)),
            ),
          for (final item in profile[section] as List? ?? [])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  item['position'],
                  item['degree'],
                  item['major'],
                  item['name'],
                  item['from'],
                  item['to'],
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                style: _style(13, color: AppColors.body),
              ),
            ),
        ],
        if (resume != null)
          TextButton.icon(
            key: const ValueKey('application-resume'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text('${resume['title']}'),
            onPressed: () {
              final uri = Uri.tryParse('${resume['url']}');
              if (uri != null &&
                  ['https', 'http'].contains(uri.scheme) &&
                  uri.host.isNotEmpty &&
                  uri.userInfo.isEmpty) {
                openLink(uri.toString());
              }
            },
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No CV PDF selected.',
              style: _style(12, color: AppColors.body),
            ),
          ),
        if (coverLetter.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Cover letter', style: _style(14, bold: true)),
          const SizedBox(height: 8),
          SelectableText(coverLetter, style: _style(13)),
        ],
      ],
    );
  }
}

class ApplyPage extends StatefulWidget {
  final JobListing job;
  final WorkflowAuthorize? authorize;
  final ApplicationsApi? api;
  const ApplyPage({super.key, required this.job, this.authorize, this.api});
  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  late final ApplicationsApi _api = widget.api ?? ApplicationsApi();
  final _cover = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _consent = false, _sending = false;
  String? _error;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _auth((t) => _api.request('GET', '/api/me/cv', t));
      if (mounted) {
        setState(() {
          _profile = result['data'] as Map<String, dynamic>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _cover.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_consent || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await _auth(
        (t) => _api.apply(
          t,
          widget.job.id,
          coverLetter: _cover.text.trim(),
          consent: _consent,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ApplicationDetailPage(
            applicationId: result.id,
            authorize: widget.authorize,
            api: widget.api,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('Apply for this role')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.job.title,
                style: _style(26, bold: true, color: AppColors.navy),
              ),
              Text(
                widget.job.company,
                style: _style(16, color: AppColors.body),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    _error!,
                    key: const ValueKey('apply-error'),
                    style: _style(13, color: AppColors.danger),
                  ),
                ),
              if (_profile == null)
                _error == null
                    ? const Center(child: CircularProgressIndicator())
                    : TextButton(
                        onPressed: _load,
                        child: const Text('Reload profile'),
                      )
              else ...[
                _card(
                  _SubmittedProfile(
                    profile: _profile!,
                    heading: 'Profile to share',
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormField(
                        key: const ValueKey('application-cover-letter'),
                        label: 'Cover letter (optional)',
                        controller: _cover,
                        maxLines: 5,
                        maxLength: 4000,
                        enabled: !_sending,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        key: const ValueKey('application-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _consent,
                        onChanged: _sending
                            ? null
                            : (v) => setState(() => _consent = v ?? false),
                        title: Text(
                          'Share this saved profile and selected CV PDF with ${widget.job.company} for this application.',
                          style: _style(13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A copy is saved when you submit. Later profile edits will not change this application.',
                        style: _style(12, color: AppColors.body),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        key: const ValueKey('submit-application'),
                        onPressed: !_consent || _sending ? null : _submit,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          _sending ? 'Submitting…' : 'Submit application',
                        ),
                      ),
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ApplicationsPage(),
                                ),
                              ),
                        child: const Text('View my applications'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
