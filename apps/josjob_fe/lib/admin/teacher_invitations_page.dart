import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing/landing_page_ascent.dart' show JosjobLandingPage;
import '../services/auth_api.dart' show AuthException;
import '../services/invitations_api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

// =========================================================================
// JosJob — Superuser: Teacher invitations (route '/admin/teacher-invitations')
//
// Superuser-only admin surface (gated in main.dart on user.isSuperuser). Lets
// a platform admin invite people to become teachers by email:
//   • "Invite a teacher" form: email + organization dropdown → send.
//   • A list of invitations (email, org, status, last sent) with a "Resend"
//     action per still-pending invitation.
//
// Mirrors JosjobWeb.Api.Admin.InvitationController via InvitationsApi. A
// standalone library.
// =========================================================================

const Color _danger = Color(0xFFD64B4B);

class TeacherInvitationsPage extends StatefulWidget {
  const TeacherInvitationsPage({super.key});

  @override
  State<TeacherInvitationsPage> createState() => _TeacherInvitationsPageState();
}

class _TeacherInvitationsPageState extends State<TeacherInvitationsPage> {
  final InvitationsApi _api = InvitationsApi();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _loading = true;
  String? _listError;
  List<TeacherInvitation> _invitations = const [];
  List<OrgOption> _orgs = const [];
  String? _selectedOrgId;

  bool _sending = false;
  String? _formError;
  String? _resendingId;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final orgs = await Session.instance.runAuthed(
        (t) => _api.listOrganizations(t),
      );
      final list = await Session.instance.runAuthed((t) => _api.list(t));
      if (!mounted) return;
      setState(() {
        _orgs = orgs;
        _selectedOrgId ??= orgs.isNotEmpty ? orgs.first.id : null;
        _invitations = list;
        _loading = false;
      });
    } on AuthException catch (e) {
      _failLoad(e.message);
    } on InvitationApiException catch (e) {
      _failLoad(e.message);
    }
  }

  void _failLoad(String message) {
    if (!mounted) return;
    setState(() {
      _listError = message;
      _loading = false;
    });
  }

  bool get _canSend =>
      _emailCtrl.text.trim().isNotEmpty && _selectedOrgId != null && !_sending;

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    final orgId = _selectedOrgId;
    if (email.isEmpty || orgId == null) return;

    setState(() {
      _sending = true;
      _formError = null;
    });
    try {
      await Session.instance.runAuthed(
        (t) => _api.create(t, email: email, organizationId: orgId),
      );
      if (!mounted) return;
      _emailCtrl.clear();
      _toast('Invitation sent to $email');
      await _load();
    } on AuthException catch (e) {
      _failSend(e.message);
    } on InvitationApiException catch (e) {
      _failSend(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _failSend(String message) {
    if (!mounted) return;
    setState(() => _formError = message);
  }

  Future<void> _resend(TeacherInvitation inv) async {
    setState(() => _resendingId = inv.id);
    try {
      await Session.instance.runAuthed((t) => _api.resend(t, inv.id));
      if (!mounted) return;
      _toast('Invitation resent to ${inv.email}');
      await _load();
    } on AuthException catch (e) {
      _toast(e.message, error: true);
    } on InvitationApiException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _resendingId = null);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13.5)),
        backgroundColor: error ? _danger : AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signOut() async {
    await Session.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Teacher invitations',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              'Sign out',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.body),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.brandBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Bp.maxContent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InviteForm(
                    emailCtrl: _emailCtrl,
                    orgs: _orgs,
                    selectedOrgId: _selectedOrgId,
                    onOrgChanged: (v) => setState(() => _selectedOrgId = v),
                    canSend: _canSend,
                    sending: _sending,
                    error: _formError,
                    onSend: _send,
                  ),
                  const SizedBox(height: 24),
                  _InvitationsCard(
                    loading: _loading,
                    error: _listError,
                    invitations: _invitations,
                    resendingId: _resendingId,
                    onResend: _resend,
                    onRetry: _load,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- invite form ---------------------------------------------------------

class _InviteForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final List<OrgOption> orgs;
  final String? selectedOrgId;
  final ValueChanged<String?> onOrgChanged;
  final bool canSend;
  final bool sending;
  final String? error;
  final VoidCallback onSend;

  const _InviteForm({
    required this.emailCtrl,
    required this.orgs,
    required this.selectedOrgId,
    required this.onOrgChanged,
    required this.canSend,
    required this.sending,
    required this.error,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;

    final email = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Email address'),
        TextField(
          controller: emailCtrl,
          enabled: !sending,
          keyboardType: TextInputType.emailAddress,
          decoration: _fieldDecoration(hint: 'teacher@example.com'),
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
          onSubmitted: (_) => canSend ? onSend() : null,
        ),
      ],
    );

    final org = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Organization'),
        DropdownButtonFormField<String>(
          initialValue: selectedOrgId,
          isExpanded: true,
          decoration: _fieldDecoration(hint: 'Select an organization'),
          icon: const Icon(Icons.expand_more_rounded, color: AppColors.body),
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
          items: orgs
              .map(
                (o) => DropdownMenuItem(
                  value: o.id,
                  child: Text(o.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: sending ? null : onOrgChanged,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite a teacher',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send an email invitation. The teacher creates their account from the '
            'link and joins the organization you choose.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.body,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: email),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: org),
              ],
            )
          else ...[
            email,
            const SizedBox(height: 16),
            org,
          ],
          if (orgs.isEmpty) ...[
            const SizedBox(height: 12),
            _ErrorText(
              'No organizations exist yet. Create one in the admin before '
              'inviting teachers.',
              tone: AppColors.body,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            _ErrorText(error!),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: _PrimaryButton(
              label: 'Send invitation',
              icon: Icons.send_rounded,
              enabled: canSend,
              loading: sending,
              onTap: onSend,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- invitations list ----------------------------------------------------

class _InvitationsCard extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<TeacherInvitation> invitations;
  final String? resendingId;
  final ValueChanged<TeacherInvitation> onResend;
  final VoidCallback onRetry;

  const _InvitationsCard({
    required this.loading,
    required this.error,
    required this.invitations,
    required this.resendingId,
    required this.onResend,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: AppColors.iconBlue,
                ),
                const SizedBox(width: 10),
                Text(
                  'Invited teachers',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                if (invitations.isNotEmpty)
                  Text(
                    '${invitations.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.body,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    if (error != null) {
      return _EmptyOrError(
        icon: Icons.error_outline_rounded,
        color: _danger,
        title: "Couldn't load invitations",
        body: error!,
        action: _SecondaryButton(label: 'Try again', onTap: onRetry),
      );
    }
    if (invitations.isEmpty) {
      return _EmptyOrError(
        icon: Icons.inbox_outlined,
        color: AppColors.iconBlue,
        title: 'No invitations yet',
        body: 'Invite a teacher above — they will appear here.',
      );
    }

    final wide = MediaQuery.of(context).size.width >= 720;
    return Column(
      children: [
        if (wide) const _HeaderRow(),
        for (var i = 0; i < invitations.length; i++) ...[
          if (i > 0 || wide) const Divider(height: 1, color: AppColors.border),
          _InvitationRow(
            inv: invitations[i],
            wide: wide,
            resending: resendingId == invitations[i].id,
            onResend: () => onResend(invitations[i]),
          ),
        ],
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    TextStyle s() => GoogleFonts.poppins(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppColors.body,
      letterSpacing: 0.3,
    );
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('EMAIL', style: s())),
          Expanded(flex: 3, child: Text('ORGANIZATION', style: s())),
          Expanded(flex: 2, child: Text('STATUS', style: s())),
          Expanded(flex: 2, child: Text('LAST SENT', style: s())),
          const SizedBox(width: 96),
        ],
      ),
    );
  }
}

class _InvitationRow extends StatelessWidget {
  final TeacherInvitation inv;
  final bool wide;
  final bool resending;
  final VoidCallback onResend;

  const _InvitationRow({
    required this.inv,
    required this.wide,
    required this.resending,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final resendBtn = _ResendButton(
      enabled: inv.isPending,
      loading: resending,
      onTap: onResend,
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                inv.email,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                inv.organizationName ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(status: inv.status),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtDate(inv.lastSentAt),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.body,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Align(alignment: Alignment.centerRight, child: resendBtn),
            ),
          ],
        ),
      );
    }

    // Narrow: stacked card row.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inv.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: inv.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${inv.organizationName ?? '—'} · sent ${_fmtDate(inv.lastSentAt)}'
            '${inv.resendCount > 0 ? ' · resent ${inv.resendCount}×' : ''}',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
          ),
          if (inv.isPending) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: resendBtn),
          ],
        ],
      ),
    );
  }
}

class _ResendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _ResendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Text(
        '—',
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
      );
    }
    return TextButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 17),
      label: Text(
        'Resend',
        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandBlue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'accepted' => ('Accepted', AppColors.tintGreen, AppColors.iconGreen),
      'revoked' => ('Revoked', AppColors.tintOrange, AppColors.iconOrange),
      _ => ('Pending', AppColors.tintBlue, AppColors.brandBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]}, ${two(d.hour)}:${two(d.minute)}';
}

// ---- shared bits ---------------------------------------------------------

class _EmptyOrError extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? action;
  const _EmptyOrError({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
    child: Column(
      children: [
        Icon(icon, size: 44, color: color),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  filled: true,
  fillColor: AppColors.bg,
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  final String message;
  final Color tone;
  const _ErrorText(this.message, {this.tone = _danger});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline_rounded, size: 17, color: tone),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12.5, color: tone, height: 1.4),
        ),
      ),
    ],
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.brandBlue,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (enabled && !loading) ? onTap : null,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 19),
                      const SizedBox(width: 9),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.brandBlue,
      side: const BorderSide(color: AppColors.brandBlue),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
    ),
  );
}
