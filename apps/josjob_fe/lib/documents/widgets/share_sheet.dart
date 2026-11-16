part of '../documents_page.dart';

// Google-Docs-style "who can access" editor for one document. Add people by
// email with an optional expiry, toggle each person's access on/off (the
// "allow" flag), and remove them. Only reachable for documents the caller can
// manage (owner / org admin / superuser).
class _ShareSheet extends StatefulWidget {
  final DocumentsApi api;
  final String docId;
  final String docTitle;

  const _ShareSheet({
    required this.api,
    required this.docId,
    required this.docTitle,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final TextEditingController _emailCtrl = TextEditingController();
  DateTime? _newExpiry;

  bool _loadingGrants = true;
  bool _busy = false;
  String? _listError;
  String? _formError;
  List<DocGrant> _grants = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loadingGrants = true;
      _listError = null;
    });
    try {
      final grants = await Session.instance.runAuthed(
        (t) => widget.api.listGrants(t, widget.docId),
      );
      if (!mounted) return;
      setState(() {
        _grants = grants;
        _loadingGrants = false;
      });
    } on AuthException {
      _setListError('Your session has expired. Please sign in again.');
    } on DocApiException catch (e) {
      _setListError(e.message);
    }
  }

  void _setListError(String msg) {
    if (!mounted) return;
    setState(() {
      _loadingGrants = false;
      _listError = msg;
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _newExpiry ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Access expires at the end of',
    );
    if (picked == null) return;
    // End of the chosen day (local), so "expires Aug 1" stays valid all day.
    setState(() {
      _newExpiry = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    });
  }

  Future<void> _share() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _formError = 'Enter an email address to share with.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await Session.instance.runAuthed(
        (t) => widget.api.addGrant(
          t,
          docId: widget.docId,
          email: email,
          validUntil: _newExpiry,
        ),
      );
      if (!mounted) return;
      _emailCtrl.clear();
      setState(() {
        _newExpiry = null;
        _busy = false;
      });
      await _reload();
    } on AuthException {
      _setFormError('Your session has expired. Please sign in again.');
    } on DocApiException catch (e) {
      _setFormError(e.message);
    }
  }

  void _setFormError(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _formError = msg;
    });
  }

  Future<void> _toggleAllow(DocGrant grant, bool value) async {
    final email = grant.email;
    if (email == null) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await Session.instance.runAuthed(
        (t) => widget.api.addGrant(
          t,
          docId: widget.docId,
          email: email,
          allow: value,
          validUntil: grant.validUntil,
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _reload();
    } on AuthException {
      _setFormError('Your session has expired. Please sign in again.');
    } on DocApiException catch (e) {
      _setFormError(e.message);
    }
  }

  Future<void> _remove(DocGrant grant) async {
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await Session.instance.runAuthed(
        (t) =>
            widget.api.deleteGrant(t, docId: widget.docId, grantId: grant.id),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _reload();
    } on AuthException {
      _setFormError('Your session has expired. Please sign in again.');
    } on DocApiException catch (e) {
      _setFormError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Share access',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.docTitle.isEmpty ? 'Untitled' : widget.docTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
              ),
              const SizedBox(height: 18),
              _addPersonForm(),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),
              Text(
                'People with access',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 10),
              _grantsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPersonForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _share(),
          decoration: _shareFieldDecoration(hint: 'Add people by email'),
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ExpiryPicker(expiry: _newExpiry, onTap: _pickExpiry),
            ),
            if (_newExpiry != null)
              IconButton(
                tooltip: 'No expiry',
                onPressed: () => setState(() => _newExpiry = null),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.body,
              ),
            const SizedBox(width: 4),
            _ShareButton(busy: _busy, onTap: _share),
          ],
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            style: GoogleFonts.poppins(fontSize: 12.5, color: _shareDanger),
          ),
        ],
      ],
    );
  }

  Widget _grantsList() {
    if (_loadingGrants) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    if (_listError != null) {
      return Text(
        _listError!,
        style: GoogleFonts.poppins(fontSize: 12.5, color: _shareDanger),
      );
    }
    if (_grants.isEmpty) {
      return Text(
        'No one else has access yet. Add someone by email above.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.body,
          height: 1.4,
        ),
      );
    }
    return Column(
      children: _grants
          .map(
            (g) => _GrantRow(
              grant: g,
              busy: _busy,
              onToggle: (v) => _toggleAllow(g, v),
              onRemove: () => _remove(g),
            ),
          )
          .toList(),
    );
  }
}

const Color _shareDanger = Color(0xFFD64B4B);

InputDecoration _shareFieldDecoration({required String hint}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.bg,
      prefixIcon: const Icon(
        Icons.mail_outline_rounded,
        size: 18,
        color: AppColors.body,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

class _ExpiryPicker extends StatelessWidget {
  final DateTime? expiry;
  final VoidCallback onTap;
  const _ExpiryPicker({required this.expiry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = expiry == null ? 'No expiry' : 'Expires ${_fmtDate(expiry!)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expiry == null ? AppColors.border : AppColors.brandBlue,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: expiry == null ? AppColors.body : AppColors.brandBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: expiry == null ? AppColors.body : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _ShareButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  'Share',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// One person on the share list: name/email, expiry + status, allow switch,
// and a remove button.
class _GrantRow extends StatelessWidget {
  final DocGrant grant;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  const _GrantRow({
    required this.grant,
    required this.busy,
    required this.onToggle,
    required this.onRemove,
  });

  bool get _scheduled {
    final from = grant.validFrom;
    return grant.allow &&
        !grant.active &&
        from != null &&
        from.isAfter(DateTime.now());
  }

  String get _statusLabel {
    if (!grant.allow) return 'Off';
    if (grant.active) return 'Active';
    // Inactive but the start date is in the future → not expired, just pending.
    return _scheduled ? 'Scheduled' : 'Expired';
  }

  Color get _statusColor {
    if (!grant.allow) return AppColors.body;
    if (grant.active) return AppColors.iconGreen;
    return _scheduled ? AppColors.iconBlue : AppColors.iconOrange;
  }

  @override
  Widget build(BuildContext context) {
    final expiryText = grant.validUntil == null
        ? 'No expiry'
        : 'Until ${_fmtDate(grant.validUntil!)}';
    final who = grant.fullName?.isNotEmpty == true
        ? grant.fullName!
        : (grant.email ?? 'Unknown');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.tintBlue,
            child: Text(
              _initial(who),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.iconBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (grant.fullName?.isNotEmpty == true && grant.email != null)
                  Text(
                    grant.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.body,
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppColors.body,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expiryText,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.body,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $_statusLabel',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(value: grant.allow, onChanged: busy ? null : onToggle),
          IconButton(
            tooltip: 'Remove',
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.body,
          ),
        ],
      ),
    );
  }

  String _initial(String s) {
    final t = s.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }
}
