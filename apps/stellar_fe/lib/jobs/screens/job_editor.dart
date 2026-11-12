part of '../jobs_page.dart';

class _JobEditor extends StatefulWidget {
  final JobsApi api;
  final JobAuthorizer authorize;
  final List<JobOrganization> organizations;
  final JobListing? job;
  const _JobEditor({
    required this.api,
    required this.authorize,
    required this.organizations,
    this.job,
  });
  @override
  State<_JobEditor> createState() => _JobEditorState();
}

class _JobEditorState extends State<_JobEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  Map<String, dynamic> _errors = {};
  String? _orgId, _error;
  String _type = 'full-time', _mode = 'onsite', _status = 'draft';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    final values = <String, String>{
      'title': job?.title ?? '',
      'description': job?.description ?? '',
      'location': job?.location ?? '',
      'industry': job?.industry ?? '',
      'requirements': job?.requirements.join('\n') ?? '',
      'highlights': job?.highlights.join('\n') ?? '',
      'salary_min': job?.salaryMin?.toString() ?? '',
      'salary_max': job?.salaryMax?.toString() ?? '',
      'currency': job?.currency ?? 'IDR',
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _orgId = job?.organizationId ?? widget.organizations.firstOrNull?.id;
    _type = job?.employmentType ?? 'full-time';
    _mode = job?.workMode ?? 'onsite';
    _status = job?.status ?? 'draft';
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errors = {};
      _error = null;
    });
    if (!_form.currentState!.validate() || _orgId == null) return;
    setState(() => _saving = true);
    final values = <String, dynamic>{
      'organization_id': _orgId,
      'employment_type': _type,
      'work_mode': _mode,
      'status': _status,
      for (final key in ['title', 'description', 'location', 'industry'])
        key: _fields[key]!.text.trim(),
      'requirements': _lines('requirements'),
      'highlights': _lines('highlights'),
      'salary_min': int.tryParse(_fields['salary_min']!.text),
      'salary_max': int.tryParse(_fields['salary_max']!.text),
      'currency': _fields['currency']!.text.trim().toUpperCase(),
    };
    try {
      await widget.authorize(
        (token) => widget.api.save(token, values, id: widget.job?.id),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
        if (e is JobsApiException) _errors = e.fields;
      });
    }
  }

  List<String> _lines(String key) => _fields[key]!.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: Text(widget.job == null ? 'Post a job' : 'Edit listing'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Make the opportunity clear.',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Describe the work, the skills you need and what candidates can expect. Salary amounts are monthly in the selected currency.',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _orgId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Organization',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.organizations
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(o.name),
                            ),
                          )
                          .toList(),
                      onChanged: widget.job == null && !_saving
                          ? (v) => setState(() => _orgId = v)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _field('title', 'Job title', max: 160),
                    _field('location', 'Location', max: 160),
                    _field('industry', 'Industry', max: 120),
                    _choice('Employment type', _type, const [
                      'full-time',
                      'part-time',
                      'internship',
                      'contract',
                      'freelance',
                    ], (v) => _type = v),
                    _choice('Work mode', _mode, const [
                      'remote',
                      'hybrid',
                      'onsite',
                    ], (v) => _mode = v),
                    _field(
                      'description',
                      'About the role',
                      lines: 6,
                      max: 20000,
                    ),
                    _field(
                      'highlights',
                      'Responsibilities (one per line)',
                      lines: 4,
                      required: false,
                      max: 6000,
                    ),
                    _field(
                      'requirements',
                      'Required skills (one per line)',
                      lines: 4,
                      required: false,
                      max: 6400,
                    ),
                    _field(
                      'salary_min',
                      'Minimum monthly salary (optional)',
                      required: false,
                      number: true,
                    ),
                    _field(
                      'salary_max',
                      'Maximum monthly salary (optional)',
                      required: false,
                      number: true,
                    ),
                    _field(
                      'currency',
                      'Currency code (for example IDR)',
                      max: 3,
                    ),
                    _choice('Listing status', _status, const [
                      'draft',
                      'active',
                      'expired',
                    ], (v) => _status = v),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('save-job'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : 'Save listing'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool required = true,
    bool number = false,
    int lines = 1,
    int? max,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('job-field-$key'),
      controller: _fields[key],
      enabled: !_saving,
      minLines: lines,
      maxLines: lines,
      maxLength: max,
      keyboardType: number
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: _errors[key]?.toString(),
      ),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) {
          return 'This field is required.';
        }
        if (key == 'currency' &&
            !RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')) {
          return 'Use a three-letter currency code.';
        }
        if (key == 'salary_max') {
          final min = int.tryParse(_fields['salary_min']!.text);
          final max = int.tryParse(value ?? '');
          if (min != null && max != null && max < min) {
            return 'Maximum must be at least the minimum.';
          }
        }
        return null;
      },
    ),
  );

  Widget _choice(
    String label,
    String value,
    List<String> options,
    void Function(String) update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: _saving
          ? null
          : (v) {
              if (v != null) setState(() => update(v));
            },
    ),
  );
}
