part of '../auth_page.dart';

// =========================================================================
// Create account
// =========================================================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Personal accounts capture these optional profile details up front so they
  // land on the account record (users.phone/address/birthdate) at register.
  final _phone = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;

  // Corporation / Institution accounts capture their organization details here
  // on the create-account form — they have no onboarding flow.
  final _orgName = TextEditingController();
  final _orgRole = TextEditingController();
  final _orgPhone = TextEditingController();
  final _orgAddress = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _agreed = false;
  String? _termsError;
  AccountType? _accountType;
  String? _typeError;
  bool _typeChosen = false;
  bool _busy = false;
  String? _error;
  String? _emailServerError;
  String? _passwordServerError;

  @override
  void initState() {
    super.initState();
    // Clear a server-side field error as soon as the user edits that field.
    _email.addListener(() {
      if (_emailServerError != null) setState(() => _emailServerError = null);
    });
    _password.addListener(() {
      if (_passwordServerError != null) {
        setState(() => _passwordServerError = null);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phone.dispose();
    _address.dispose();
    _orgName.dispose();
    _orgRole.dispose();
    _orgPhone.dispose();
    _orgAddress.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final formOk = _formKey.currentState?.validate() ?? false;
    final termsOk = _agreed;
    setState(() {
      _termsError = termsOk
          ? null
          : 'Please accept the Terms to create your account.';
    });
    if (!formOk) {
      // Focus the first invalid basic field. If only the organization detail
      // fields are invalid (they have no focus nodes), leave focus put — their
      // inline errors already show — rather than stealing it to the valid
      // password field.
      if (_validateName(_name.text) != null) {
        _nameFocus.requestFocus();
      } else if (_validateEmail(_email.text) != null) {
        _emailFocus.requestFocus();
      } else if (_validatePassword(_password.text) != null) {
        _passwordFocus.requestFocus();
      }
      return;
    }
    if (!termsOk) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final org = _accountType == AccountType.organization;
      // Personal accounts send the profile fields captured above; organization
      // accounts reuse their (required) org phone/address and carry no DOB.
      final user = await Session.instance.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        accountType: _accountType!,
        phone: _blankToNull(org ? _orgPhone.text : _phone.text),
        address: _blankToNull(org ? _orgAddress.text : _address.text),
        birthdate: org || _dob == null ? null : _isoDate(_dob!),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      // Corporation / Institution accounts collected everything they need on
      // this form and have no onboarding — go straight to the "request received"
      // acknowledgement. Personal accounts continue into the onboarding flow.
      if (_accountType == AccountType.organization) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrgPendingPage()),
        );
        return;
      }
      final firstName = user.firstName.isNotEmpty
          ? user.firstName
          : _name.text.trim().split(' ').first;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnboardingFlow(firstName: firstName)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _emailServerError = e.fieldErrors['email'];
        _passwordServerError = e.fieldErrors['password'];
      });
      // Surface server-side field errors and jump to the first offender.
      _formKey.currentState?.validate();
      if (_emailServerError != null) {
        _emailFocus.requestFocus();
      } else if (_passwordServerError != null) {
        _passwordFocus.requestFocus();
      }
    }
  }

  // Step 1 gate: a registration type must be chosen before the sign-up methods
  // appear, so the choice covers both email/password and Google.
  void _confirmType() {
    if (_accountType == null) {
      setState(() => _typeError = 'Please choose a registration type.');
      return;
    }
    setState(() => _typeChosen = true);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      brandHeadline: 'Start your ascent.',
      brandSub:
          'Create your free account and begin building real, job-ready skills '
          '— right where you work.',
      brandPoints: const [
        'Self-paced modules with quizzes & assessments',
        'Live coaching, anywhere, via live streaming',
        'Earn recognised industry certifications',
      ],
      child: _AuthFormBody(
        title: 'Create your account',
        subtitle: _typeChosen
            ? 'Start upgrading your skills with JosJob.'
            : "First, tell us who's signing up.",
        form: _typeChosen ? _buildForm() : _buildTypeStep(),
        footerPrompt: 'Already have an account?',
        footerAction: 'Log in',
        onFooter: _busy
            ? null
            : () => Navigator.of(context).pushReplacementNamed('/login'),
      ),
    );
  }

  // Step 1 — pick Personal vs Corporation/Institution, then Continue.
  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountTypeField(
          value: _accountType,
          enabled: !_busy,
          error: _typeError,
          onChanged: (t) => setState(() {
            _accountType = t;
            _typeError = null;
            // A pending "work email required" error is organization-specific;
            // drop just that one when the type changes (a duplicate-email
            // error, if any, still applies).
            if (_emailServerError != null &&
                _emailServerError!.contains('work email')) {
              _emailServerError = null;
            }
          }),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(label: 'Continue', busy: false, onPressed: _confirmType),
      ],
    );
  }

  // Step 2 — the sign-up form + Google, with the chosen type shown and carried
  // into whichever method the user picks.
  Widget _buildForm() {
    final org = _accountType == AccountType.organization;
    final typeLabel = org ? 'Corporation or Institution' : 'Personal';
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) _FormError(_error!),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tintBlue,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(
                    org ? Icons.business_outlined : Icons.person_outline,
                    size: 20,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registering as',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.body,
                          ),
                        ),
                        Text(
                          typeLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _typeChosen = false),
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _AuthField(
              label: 'Full name',
              hint: 'Jordan Lee',
              icon: Icons.person_outline,
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_busy,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: _validateName,
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
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
              validator: (v) => _validateEmail(v) ?? _emailServerError,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            _AuthField(
              label: 'Password',
              hint: 'Create a password',
              icon: Icons.lock_outline,
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !_busy,
              obscure: true,
              helper: 'At least 8 characters.',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => _validatePassword(v) ?? _passwordServerError,
              onSubmitted: (_) => _submit(),
            ),
            // Personal accounts optionally add these profile details up front;
            // they persist on the account record and populate the admin view.
            if (!org) ...[
              const SizedBox(height: 18),
              _AuthField(
                label: 'Phone (optional)',
                hint: 'e.g. +62 812 3456 7890',
                icon: Icons.phone_outlined,
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 18),
              _AuthField(
                label: 'Address (optional)',
                hint: 'City, Country',
                icon: Icons.location_on_outlined,
                controller: _address,
                enabled: !_busy,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
              ),
              const SizedBox(height: 18),
              _DateField(
                label: 'Date of birth (optional)',
                hint: 'Select your date of birth',
                icon: Icons.cake_outlined,
                value: _dob,
                enabled: !_busy,
                onChanged: (d) => setState(() => _dob = d),
              ),
            ],
            // Organization accounts capture their mandatory details here — they
            // have no onboarding flow, so everything is collected up front.
            if (org) ...[
              const SizedBox(height: 18),
              _AuthField(
                label: 'Organization name',
                hint: 'Acme Industries',
                icon: Icons.apartment_outlined,
                controller: _orgName,
                enabled: !_busy,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.organizationName],
                validator: _validateRequired,
              ),
              const SizedBox(height: 18),
              _AuthField(
                label: 'Your role in the organization',
                hint: 'e.g. HR Manager',
                icon: Icons.badge_outlined,
                controller: _orgRole,
                enabled: !_busy,
                keyboardType: TextInputType.text,
                validator: _validateRequired,
              ),
              const SizedBox(height: 18),
              _AuthField(
                label: 'Phone',
                hint: 'e.g. +62 812 3456 7890',
                icon: Icons.phone_outlined,
                controller: _orgPhone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: _validateRequired,
              ),
              const SizedBox(height: 18),
              _AuthField(
                label: 'Address',
                hint: 'City, Country',
                icon: Icons.location_on_outlined,
                controller: _orgAddress,
                enabled: !_busy,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
                validator: _validateRequired,
              ),
            ],
            const SizedBox(height: 16),
            _TermsCheck(
              value: _agreed,
              error: _termsError,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _agreed = v;
                      if (v) _termsError = null;
                    }),
              onLink: () => _soon(context, 'Terms & Privacy'),
            ),
            const SizedBox(height: 18),
            _PrimaryButton(
              label: 'Create account',
              busy: _busy,
              onPressed: _submit,
            ),
            // Google sign-up is offered for personal accounts only — an
            // organization must supply the details above, which the Google flow
            // can't collect, so email/password is the only path for them.
            if (!org) ...[
              const _OrDivider(),
              _SocialRow(enabled: !_busy, accountType: _accountType),
            ],
          ],
        ),
      ),
    );
  }
}
