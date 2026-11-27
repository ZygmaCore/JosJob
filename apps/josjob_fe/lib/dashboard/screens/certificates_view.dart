import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/certificates_api.dart';
import '../../services/open_link.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../shared/app_ui.dart';
import '../../shared/app_form_field.dart';
import '../../learning/course_award_card.dart';

typedef CertificateAuthorize =
    Future<T> Function<T>(Future<T> Function(String) call);

class CertificatesView extends StatefulWidget {
  final CertificatesApi? api;
  final CertificateAuthorize? authorize;
  final void Function(String)? onOpenLink;
  const CertificatesView({
    super.key,
    this.api,
    this.authorize,
    this.onOpenLink,
  });
  @override
  State<CertificatesView> createState() => _CertificatesViewState();
}

class _CertificatesViewState extends State<CertificatesView> {
  late final _api = widget.api ?? CertificatesApi();
  List<LearnerCertificate> _certificates = [];
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
    if (widget.api == null) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _auth(_api.fetch);
      if (mounted && generation == _generation) {
        setState(() => _certificates = items);
      }
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

  Future<void> _edit([LearnerCertificate? certificate]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CertificateEditor(
        certificate: certificate,
        save: (attrs) => _auth((t) => _api.save(t, attrs, id: certificate?.id)),
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _delete(LearnerCertificate c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete certificate?'),
        content: Text('Remove “${c.title}” from your certificates?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep certificate'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete certificate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth((t) => _api.delete(t, c.id));
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
  Widget _card(Widget child, {Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('certificates-view'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My certificates', style: _style(26, bold: true)),
                const SizedBox(height: 6),
                Text(
                  'Keep your qualifications and issuer details together.',
                  style: _style(13, color: AppColors.body),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('refresh-certificates'),
            tooltip: 'Refresh certificates',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            _loading
                ? 'Loading certificates…'
                : _error != null
                ? 'Certificate list unavailable'
                : '${_certificates.length} ${_certificates.length == 1 ? 'certificate' : 'certificates'} saved',
            style: _style(14, bold: true),
          ),
          FilledButton.icon(
            key: const ValueKey('add-certificate'),
            onPressed: _loading || _busy ? null : _edit,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add certificate'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _card(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 20,
              color: AppColors.brandBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Course completion certificates use your confirmed CV name and lock it after issuance. Certificates you add yourself and onboarding records are self-reported.',
                style: _style(13, color: AppColors.body),
              ),
            ),
          ],
        ),
      ),
      if (_loading)
        _card(const Center(child: CircularProgressIndicator()))
      else if (_error != null)
        _card(
          Column(
            children: [
              Text(_error!, style: _style(14)),
              TextButton(
                key: const ValueKey('retry-certificates'),
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        )
      else if (_certificates.isEmpty)
        _card(
          const AppStateView(
            key: ValueKey('empty-certificates'),
            icon: Icons.workspace_premium_outlined,
            title: 'No certificates yet',
            message:
                'Add a certificate you hold to keep a record of your qualifications.',
          ),
        )
      else
        for (final c in _certificates) _certificate(c),
    ],
  );
  Widget _certificate(LearnerCertificate c) => c.source == 'course_completion'
      ? CourseAwardCard(
          authorize: _auth,
          award: {
            'id': c.id,
            'title': c.title,
            'recipient_name': c.recipientName,
            'name_locked': c.nameLocked,
            'skill_tags': c.skillTags,
            'issued_on': c.issuedOn,
            'credential_id': c.credentialId,
          },
        )
      : _card(
          key: ValueKey('certificate-${c.id}'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.tintBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: _style(17, bold: true)),
                        const SizedBox(height: 4),
                        Text(
                          c.issuer.isEmpty ? 'Issuer not provided' : c.issuer,
                          style: _style(14, color: AppColors.body),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      c.source == 'onboarding'
                          ? 'From onboarding · self-reported'
                          : 'Self-reported',
                    ),
                  ),
                  if (c.expired) const Chip(label: Text('Expired')),
                ],
              ),
              if (c.issuedOn != null) _detail('Issued', c.issuedOn!),
              if (c.expiresOn != null) _detail('Expires', c.expiresOn!),
              if (c.recordedPeriod?.isNotEmpty == true)
                _detail('Recorded period', c.recordedPeriod!),
              if (c.credentialId?.isNotEmpty == true)
                _detail('Credential ID', c.credentialId!),
              if (c.source == 'onboarding')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'This record comes from your onboarding answers.',
                    style: _style(12, color: AppColors.body),
                  ),
                ),
              if (c.editable || c.credentialUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (c.credentialUrl != null)
                        OutlinedButton.icon(
                          onPressed: () =>
                              (widget.onOpenLink ?? openLink)(c.credentialUrl!),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open credential'),
                        ),
                      if (c.editable) ...[
                        TextButton.icon(
                          key: ValueKey('edit-certificate-${c.id}'),
                          onPressed: _busy ? null : () => _edit(c),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          key: ValueKey('delete-certificate-${c.id}'),
                          onPressed: _busy ? null : () => _delete(c),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text('Delete'),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text('$label: $value', style: _style(13, color: AppColors.body)),
  );
}

class _CertificateEditor extends StatefulWidget {
  final LearnerCertificate? certificate;
  final Future<void> Function(Map<String, dynamic>) save;
  const _CertificateEditor({this.certificate, required this.save});
  @override
  State<_CertificateEditor> createState() => _CertificateEditorState();
}

class _CertificateEditorState extends State<_CertificateEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.certificate?.title);
  late final _issuer = TextEditingController(text: widget.certificate?.issuer);
  late final _issued = TextEditingController(
    text: widget.certificate?.issuedOn,
  );
  late final _expires = TextEditingController(
    text: widget.certificate?.expiresOn,
  );
  late final _credential = TextEditingController(
    text: widget.certificate?.credentialId,
  );
  late final _url = TextEditingController(
    text: widget.certificate?.credentialUrl,
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _issuer, _issued, _expires, _credential, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await widget.save({
        'title': _title.text.trim(),
        'issuer': _issuer.text.trim(),
        'issued_on': optional(_issued),
        'expires_on': optional(_expires),
        'credential_id': optional(_credential),
        'credential_url': optional(_url),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _dateError(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final text = value.trim(), date = DateTime.tryParse(value.trim());
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
            date != null &&
            date.toIso8601String().startsWith(text)
        ? null
        : 'Use YYYY-MM-DD';
  }

  Future<void> _pick(TextEditingController c) async {
    final now = DateTime.now();
    final first = DateTime(1900);
    final last = c == _issued ? now : DateTime(2100, 12, 31);
    final parsed = DateTime.tryParse(c.text) ?? now;
    final initial = parsed.isBefore(first)
        ? first
        : (parsed.isAfter(last) ? last : parsed);
    final date = await showDatePicker(
      context: context,
      builder: appFormDialog,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date != null) {
      c.text =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool required = false,
    bool date = false,
    int max = 200,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppFormField(
      label: label,
      hint: date ? 'YYYY-MM-DD' : (c == _url ? 'https://…' : null),
      controller: c,
      enabled: !_saving,
      maxLength: max,
      keyboardType: date
          ? TextInputType.datetime
          : (c == _url ? TextInputType.url : TextInputType.text),
      suffixIcon: date
          ? IconButton(
              tooltip: 'Choose $label',
              onPressed: _saving ? null : () => _pick(c),
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
            )
          : null,
      validator: (value) {
        if (required && (value?.trim().length ?? 0) < 2) {
          return 'Enter at least 2 characters';
        }
        if (date) {
          return _dateError(value);
        }
        if (c == _url && value?.trim().isNotEmpty == true) {
          final uri = Uri.tryParse(value!.trim());
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            return 'Enter a full http or https URL';
          }
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Theme(
      data: appFormTheme(context),
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        title: Text(
          widget.certificate == null ? 'Add certificate' : 'Edit certificate',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter the details supplied by your certificate issuer. Dates and credential details are optional.',
                  ),
                  const SizedBox(height: 20),
                  _field('Certificate title', _title, required: true),
                  _field('Issuer', _issuer, required: true),
                  _field(
                    'Issue date (YYYY-MM-DD)',
                    _issued,
                    date: true,
                    max: 10,
                  ),
                  _field(
                    'Expiry date (YYYY-MM-DD)',
                    _expires,
                    date: true,
                    max: 10,
                  ),
                  _field('Credential ID', _credential),
                  _field('Credential URL', _url, max: 2000),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const ValueKey('certificate-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('save-certificate'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save certificate'),
          ),
        ],
      ),
    ),
  );
}
