part of '../auth_page.dart';

// =========================================================================
// Log in
// =========================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _remember = true;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      // Focus-management: move focus to the first invalid field.
      if (_validateEmail(_email.text) != null) {
        _emailFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await Session.instance.login(
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
      );
      if (!mounted) return;
      // Corporation / Institution accounts are pending review and have no
      // onboarding or dashboard — always send them to the acknowledgement.
      if (user.accountType == AccountType.organization) {
        // Un-provisioned org accounts are pending review; approved ones go
        // straight to the welcome-back → dashboard path (org accounts never
        // run onboarding).
        if (!user.approved) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrgPendingPage()),
          );
          return;
        }
        setState(() {
          _busy = false;
          _done = true;
        });
        return;
      }
      // Un-onboarded users (registered but never finished) go to onboarding;
      // fully onboarded users get the welcome-back screen → dashboard.
      if (!user.mandatoryCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingFlow(firstName: user.firstName),
          ),
        );
        return;
      }
      setState(() {
        _busy = false;
        _done = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  String _welcomeTitle() {
    final name = Session.instance.user?.firstName ?? '';
    return name.isEmpty ? 'Welcome back!' : 'Welcome back, $name!';
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      brandHeadline: 'Pick up right\nwhere you left off.',
      brandSub:
          'Log back in to keep learning and get matched — your courses, '
          'coaching, and job matches are waiting.',
      brandPoints: const [
        'Learn where you work, at your own pace',
        'Live coaching via live streaming',
        'AI job matching to live vacancies',
      ],
      child: _done
          ? _AuthSuccess(
              title: _welcomeTitle(),
              message:
                  "You're signed in. Jump into your dashboard to keep "
                  'learning and see your latest job matches.',
              cta: 'Go to dashboard',
              onCta: () => _goDashboard(context),
            )
          : _AuthFormBody(
              title: 'Welcome back',
              subtitle: 'Log in to your JosJob account.',
              form: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) _FormError(_error!),
                      _AuthField(
                        label: 'Email',
                        hint: 'you@email.com',
                        icon: Icons.mail_outline,
                        controller: _email,
                        focusNode: _emailFocus,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 18),
                      _AuthField(
                        label: 'Password',
                        hint: 'Your password',
                        icon: Icons.lock_outline,
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !_busy,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password.'
                            : null,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _RememberMe(
                            value: _remember,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _remember = v),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _soon(context, 'Password reset'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brandBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PrimaryButton(
                        label: 'Log in',
                        busy: _busy,
                        onPressed: _submit,
                      ),
                      const _OrDivider(),
                      _SocialRow(enabled: !_busy),
                    ],
                  ),
                ),
              ),
              footerPrompt: "New to JosJob?",
              footerAction: 'Create an account',
              onFooter: _busy
                  ? null
                  : () =>
                        Navigator.of(context).pushReplacementNamed('/register'),
            ),
    );
  }
}
