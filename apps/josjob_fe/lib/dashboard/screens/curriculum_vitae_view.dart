import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/curriculum_vitae_api.dart';
import '../../services/open_link.dart';
import '../../services/session.dart';
import '../../shared/app_form_field.dart';
import '../../theme/app_theme.dart';
import 'certificates_view.dart';

typedef CvAuthorize = Future<T> Function<T>(Future<T> Function(String) call);

class CurriculumVitaeView extends StatefulWidget {
  final CurriculumVitaeApi? api;
  final CvAuthorize? authorize;
  final void Function(String)? onOpenLink;
  final Future<void> Function()? onManageCertificates;
  const CurriculumVitaeView({
    super.key,
    this.api,
    this.authorize,
    this.onOpenLink,
    this.onManageCertificates,
  });
  @override
  State<CurriculumVitaeView> createState() => _CurriculumVitaeViewState();
}

class _CurriculumVitaeViewState extends State<CurriculumVitaeView> {
  late final _api = widget.api ?? CurriculumVitaeApi();
  CurriculumVitaeData? _data;
  bool _loading = true, _busy = false;
  String? _error;
  int _generation = 0;
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
      final data = await _auth(_api.fetch);
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CvEditor(
        data: _data!,
        save: (attrs) => _auth((token) => _api.save(token, attrs)),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _matchingCv() async {
    await Navigator.of(context).pushNamed('/jobs');
    if (mounted) await _load();
  }

  Future<void> _certificates() async {
    if (widget.onManageCertificates != null) {
      await widget.onManageCertificates!();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              title: Text('Certificates', style: _style(20, bold: true)),
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: const CertificatesView(),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  Future<void> _detach() async {
    setState(() => _busy = true);
    try {
      await _auth((t) => _api.save(t, {'resume_document_id': null}));
      if (mounted) await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
  Widget _card(String title, Widget content, {Widget? action, Key? key}) =>
      Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 12,
              children: [
                Text(title, style: _style(18, bold: true)),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      );
  Widget _button(
    String text,
    VoidCallback action, {
    Key? key,
    bool disabled = false,
  }) => TextButton(
    key: key,
    onPressed: disabled ? null : action,
    style: TextButton.styleFrom(textStyle: _style(13, bold: true)),
    child: Text(text),
  );
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('curriculum-vitae'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Curriculum vitae', style: _style(26, bold: true)),
          ),
          IconButton(
            key: const ValueKey('refresh-cv'),
            tooltip: 'Refresh CV',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh, color: AppColors.brandBlue),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Your saved profile, experience, qualifications and resume PDF.',
        style: _style(13, color: AppColors.body),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('cv-find-job-matches'),
          onPressed: _matchingCv,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Upload or update matching CV'),
        ),
      ),
      const SizedBox(height: 24),
      if (_loading)
        _card(
          'Loading your CV',
          const Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _card(
          'CV unavailable',
          Column(
            children: [
              Text(_error!, style: _style(14)),
              _button('Try again', _load, key: const ValueKey('retry-cv')),
            ],
          ),
        )
      else if (_data != null)
        ..._content(_data!),
    ],
  );
  List<Widget> _content(CurriculumVitaeData d) => [
    _card(
      d.fullName.isEmpty ? 'Your profile' : d.fullName,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.headline != null)
            Text(d.headline!, style: _style(16, bold: true))
          else
            Text(
              'Add a headline to introduce your professional focus.',
              style: _style(14, color: AppColors.body),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _contact(Icons.mail_outline, d.email),
              if (d.phone != null) _contact(Icons.phone_outlined, d.phone!),
              if (d.location != null)
                _contact(Icons.place_outlined, d.location!),
            ],
          ),
        ],
      ),
      action: _button(
        'Edit CV details',
        _edit,
        key: const ValueKey('edit-cv'),
        disabled: _busy,
      ),
    ),
    _card(
      'Resume PDF',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.resumeDocument?.title ?? 'No resume PDF attached',
            key: const ValueKey('cv-pdf-title'),
            style: _style(
              14,
              bold: d.resumeDocument != null,
              color: d.resumeDocument == null ? AppColors.body : AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (d.resumeDocument != null)
                FilledButton.icon(
                  key: const ValueKey('open-cv-pdf'),
                  onPressed: () =>
                      (widget.onOpenLink ?? openLink)(d.resumeDocument!.url),
                  style: FilledButton.styleFrom(
                    textStyle: _style(13, bold: true),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open PDF'),
                ),
              _button(
                'Choose saved PDF',
                _edit,
                key: const ValueKey('choose-cv-pdf'),
                disabled: _busy,
              ),
              if (d.resumeDocument != null)
                _button(
                  'Detach PDF',
                  _detach,
                  key: const ValueKey('detach-cv-pdf'),
                  disabled: _busy,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a PDF you already own from your document library. Detaching keeps the original document.',
            style: _style(12, color: AppColors.body),
          ),
        ],
      ),
    ),
    _card(
      'Professional summary',
      Text(
        d.summary ?? 'Add a summary of your experience and career goals.',
        key: const ValueKey('cv-summary'),
        style: _style(
          14,
          color: d.summary == null ? AppColors.body : AppColors.navy,
        ),
      ),
    ),
    _card(
      'Your background',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your saved CV details are shared when you apply. Review your skills with Edit CV details.',
            style: _style(13, color: AppColors.body),
          ),
          const SizedBox(height: 16),
          _entries('Work experience', d.experience, false),
          const SizedBox(height: 22),
          _entries('Education', d.education, true),
          const SizedBox(height: 22),
          Text('Skills', style: _style(16, bold: true)),
          const SizedBox(height: 12),
          if (d.skills.isEmpty)
            Text(
              'No skills added yet.',
              style: _style(13, color: AppColors.body),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in d.skills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(skill, style: _style(12)),
                  ),
              ],
            ),
        ],
      ),
    ),
    _card(
      'Certifications',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d.certificates.isEmpty)
            Text(
              'No certificates saved yet.',
              style: _style(13, color: AppColors.body),
            ),
          for (final c in d.certificates)
            Padding(
              key: ValueKey('cv-certificate-${c.id}'),
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: _style(14, bold: true)),
                  Text(
                    c.issuer.isEmpty ? 'Issuer not provided' : c.issuer,
                    style: _style(13, color: AppColors.body),
                  ),
                  Text(
                    '${c.source == 'onboarding' ? 'From onboarding · ' : ''}Self-reported${c.expired ? ' · Expired' : ''}',
                    style: _style(12, color: AppColors.body),
                  ),
                  if (c.issuedOn != null)
                    Text(
                      'Issued: ${c.issuedOn}',
                      style: _style(12, color: AppColors.body),
                    ),
                  if (c.expiresOn != null)
                    Text(
                      'Expires: ${c.expiresOn}',
                      style: _style(12, color: AppColors.body),
                    ),
                  if (c.recordedPeriod?.isNotEmpty == true)
                    Text(
                      'Recorded period: ${c.recordedPeriod}',
                      style: _style(12, color: AppColors.body),
                    ),
                  if (c.credentialUrl != null)
                    _button(
                      'Open credential',
                      () => (widget.onOpenLink ?? openLink)(c.credentialUrl!),
                    ),
                ],
              ),
            ),
        ],
      ),
      action: _button(
        'Manage certificates',
        _certificates,
        key: const ValueKey('manage-cv-certificates'),
        disabled: _busy,
      ),
    ),
  ];
  Widget _contact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.body),
      const SizedBox(width: 7),
      Flexible(
        child: Text(text, style: _style(13, color: AppColors.body)),
      ),
    ],
  );
  Widget _entries(
    String title,
    List<CvBackgroundEntry> entries,
    bool education,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: _style(16, bold: true)),
      const SizedBox(height: 12),
      if (entries.isEmpty)
        Text(
          education
              ? 'No education added yet.'
              : 'No work experience added yet.',
          style: _style(13, color: AppColors.body),
        ),
      for (final (i, e) in entries.indexed)
        Padding(
          key: ValueKey('cv-${education ? 'education' : 'experience'}-$i'),
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                education
                    ? _qualification(e)
                    : e.position ?? 'Role not provided',
                style: _style(14, bold: true),
              ),
              Text(e.name ?? 'Employer not provided', style: _style(13)),
              Text(e.period, style: _style(12, color: AppColors.body)),
              if (e.country != null)
                Text(e.country!, style: _style(12, color: AppColors.body)),
              if (!education && e.internship)
                Text('Internship', style: _style(12, color: AppColors.body)),
            ],
          ),
        ),
    ],
  );

  String _qualification(CvBackgroundEntry entry) {
    final value = [
      entry.degree,
      entry.major,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return value.isEmpty ? 'Qualification not provided' : value;
  }
}

class _CvEditor extends StatefulWidget {
  final CurriculumVitaeData data;
  final Future<void> Function(Map<String, dynamic>) save;
  const _CvEditor({required this.data, required this.save});
  @override
  State<_CvEditor> createState() => _CvEditorState();
}

class _CvEditorState extends State<_CvEditor> {
  late final _headline = TextEditingController(text: widget.data.headline),
      _summary = TextEditingController(text: widget.data.summary),
      _skills = TextEditingController(text: widget.data.skills.join(', '));
  late String _document = widget.data.resumeDocument?.id ?? '';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _headline.dispose();
    _summary.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final skills = _skills.text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (skills.length > 100 || skills.any((s) => s.length > 100)) {
      setState(
        () => _error = 'Use up to 100 skills, each at most 100 characters.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save({
        'headline': _headline.text.trim(),
        'summary': _summary.text.trim(),
        'skills': skills,
        'resume_document_id': _document.isEmpty ? null : _document,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Theme(
      data: appFormTheme(context),
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        title: const Text(
          'Edit CV details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormField(
                  label: 'Professional headline',
                  hint: 'Your professional focus',
                  controller: _headline,
                  maxLength: 200,
                  enabled: !_saving,
                ),
                const SizedBox(height: 18),
                AppFormField(
                  label: 'Professional summary',
                  hint: 'Your experience and career goals',
                  controller: _summary,
                  maxLength: 4000,
                  maxLines: 5,
                  enabled: !_saving,
                ),
                const SizedBox(height: 18),
                AppFormField(
                  key: const ValueKey('cv-edit-skills'),
                  label: 'Skills',
                  hint: 'For example: SQL, JavaScript, Communication',
                  controller: _skills,
                  maxLines: 3,
                  maxLength: 10000,
                  enabled: !_saving,
                ),
                const Text(
                  'Separate skills with commas. Changes update job matching and future applications.',
                ),
                const SizedBox(height: 18),
                Text(
                  'Resume PDF',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Semantics(
                  label: 'Resume PDF',
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('cv-document-select'),
                    initialValue: _document,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No PDF attached'),
                      ),
                      for (final d in widget.data.pdfDocuments)
                        DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _document = value ?? ''),
                  ),
                ),
                if (widget.data.pdfDocuments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'No saved PDF documents are available for your account.',
                    ),
                  ),
                const SizedBox(height: 14),
                const Text(
                  'Work history and education are imported from your matching CV or saved onboarding details.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      key: const ValueKey('cv-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('save-cv'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save CV details'),
          ),
        ],
      ),
    ),
  );
}
