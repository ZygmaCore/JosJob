import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/invitations_api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

// =========================================================================
// JosJob — Accept a teacher invitation (route '/invite?token=…')
//
// Opened from the invitation email link. Flow:
//   1. GET /api/invitations/:token  → show the invited email + organization.
//   2. The invitee sets their full name + password (create-account form).
//   3. POST /api/invitations/:token/accept:
//        • new account  → tokens returned → sign in → teacher dashboard.
//        • existing email → provision role only → send them to normal login.
//
// Public (no session required). A standalone library.
// =========================================================================

const Color _danger = Color(0xFFD64B4B);

class InviteAcceptPage extends StatefulWidget {
  final String? token;
  const InviteAcceptPage({super.key, required this.token});

  @override
  State<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

enum _Phase { loading, form, submitting, invalid, existing }

class _InviteAcceptPageState extends State<InviteAcceptPage> {
  final InvitationsApi _api = InvitationsApi();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  final TextEditingController _pw2Ctrl = TextEditingController();

  _Phase _phase = _Phase.loading;
  InvitationInfo? _info;
  String? _invalidMessage;
  String? _formError;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _fetch() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      setState(() {
        _phase = _Phase.invalid;
        _invalidMessage = 'This invitation link is missing its token.';
      });
      return;
    }
    try {
      final info = await _api.fetch(token);
      if (!mounted) return;
      setState(() {
        _info = info;
        _phase = _Phase.form;
      });
    } on InvitationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.invalid;
        _invalidMessage = e.message;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (name.isEmpty) {
      setState(() => _formError = 'Please enter your full name.');
      return;
    }
    if (pw.length < 8) {
      setState(() => _formError = 'Password must be at least 8 characters.');
      return;
    }
    if (pw != pw2) {
      setState(() => _formError = 'The passwords do not match.');
      return;
    }

    setState(() {
      _phase = _Phase.submitting;
      _formError = null;
    });

    try {
      final result = await _api.accept(
        widget.token!,
        fullName: name,
        password: pw,
      );

      if (result.isNewUser && result.session != null) {
        await Session.instance.signInWithSession(result.session!);
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      } else {
        // Email already had an account — provisioned as teacher; log in normally.
        if (!mounted) return;
        setState(() => _phase = _Phase.existing);
      }
    } on InvitationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _formError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.loading:
        return const _LoadingCard();
      case _Phase.invalid:
        return _InvalidCard(message: _invalidMessage ?? 'Invalid invitation.');
      case _Phase.existing:
        return _ExistingCard(
          email: _info?.email ?? '',
          onLogin: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false),
        );
      case _Phase.form:
      case _Phase.submitting:
        return _form(submitting: _phase == _Phase.submitting);
    }
  }

  Widget _form({required bool submitting}) {
    final info = _info!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Brand(),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "You've been invited to teach",
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  info.organizationName == null
                      ? 'Create your teacher account to get started.'
                      : 'Join ${info.organizationName} as a Teacher. '
                            'Create your account to get started.',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: AppColors.body,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),

                const _FieldLabel('Email'),
                _ReadOnlyField(value: info.email),

                const SizedBox(height: 18),
                const _FieldLabel('Full name'),
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  enabled: !submitting,
                  decoration: _fieldDecoration(hint: 'e.g. Jamie Rivera'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),

                const SizedBox(height: 18),
                const _FieldLabel('Password'),
                TextField(
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  enabled: !submitting,
                  decoration: _fieldDecoration(
                    hint: 'At least 8 characters',
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.body,
                      ),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),

                const SizedBox(height: 18),
                const _FieldLabel('Confirm password'),
                TextField(
                  controller: _pw2Ctrl,
                  obscureText: _obscure,
                  enabled: !submitting,
                  onSubmitted: (_) => submitting ? null : _submit(),
                  decoration: _fieldDecoration(hint: 'Re-enter your password'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  _ErrorText(_formError!),
                ],

                const SizedBox(height: 24),
                _PrimaryButton(
                  label: 'Create teacher account',
                  loading: submitting,
                  onTap: submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- brand / cards -------------------------------------------------------

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.heroBlue, AppColors.brandBlue],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
      ),
      const SizedBox(height: 10),
      Text(
        'JosJob',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => _CenteredCard(
    children: [
      const SizedBox(
        width: 38,
        height: 38,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Checking your invitation…',
        style: GoogleFonts.poppins(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _InvalidCard extends StatelessWidget {
  final String message;
  const _InvalidCard({required this.message});

  @override
  Widget build(BuildContext context) => _CenteredCard(
    children: [
      const Icon(Icons.link_off_rounded, size: 50, color: _danger),
      const SizedBox(height: 16),
      Text(
        'Invitation unavailable',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          color: AppColors.body,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 22),
      _PrimaryButton(
        label: 'Go to sign in',
        onTap: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false),
      ),
    ],
  );
}

class _ExistingCard extends StatelessWidget {
  final String email;
  final VoidCallback onLogin;
  const _ExistingCard({required this.email, required this.onLogin});

  @override
  Widget build(BuildContext context) => _CenteredCard(
    children: [
      const Icon(
        Icons.verified_user_outlined,
        size: 50,
        color: AppColors.iconGreen,
      ),
      const SizedBox(height: 16),
      Text(
        "You're all set as a teacher",
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$email already has an account, so we added the teacher role to it. '
        'Sign in to reach your teacher workspace.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          color: AppColors.body,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 22),
      _PrimaryButton(label: 'Sign in', onTap: onLogin),
    ],
  );
}

// ---- field chrome --------------------------------------------------------

InputDecoration _fieldDecoration({required String hint, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.bg,
      suffixIcon: suffix,
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

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.tintBlue.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.body),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ),
        const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.body),
      ],
    ),
  );
}

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
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline_rounded, size: 17, color: _danger),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: _danger,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !loading ? 0.5 : 1,
      child: Material(
        color: AppColors.brandBlue,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CenteredCard extends StatelessWidget {
  final List<Widget> children;
  const _CenteredCard({required this.children});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
