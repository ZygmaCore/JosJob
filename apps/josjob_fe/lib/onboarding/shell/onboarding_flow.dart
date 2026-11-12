part of '../onboarding_page.dart';

// =========================================================================
// Flow controller
// =========================================================================
class OnboardingFlow extends StatefulWidget {
  final String? firstName;
  const OnboardingFlow({super.key, this.firstName});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  // null role => "Who you are" identity screen. Once a role is confirmed there,
  // [_step] walks 0..2 through the three content steps; _step == 3 is the
  // completion screen.
  OnboardRole? _role;
  int _step = 0;
  bool _forward = true; // drives slide direction of the page transition
  bool _submitting = false;

  // Set when confirming the identity step fails backend validation — currently
  // the work-email rule (an organization account on a free-provider email).
  // Shown inline on the "Who you are" screen; cleared on the next attempt.
  String? _identityError;

  // Identity ("Who you are") — pre-filled from the (simulated) signed-in
  // account. [_pendingRole] holds the registration-type sub-role until the
  // user confirms and enters the steps.
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  OnboardRole? _pendingRole;

  // Selected country name (from master data) for the identity step; drives the
  // phone dial code and is synced with a resolved country_id.
  String? _country;

  // E.164 dial code for the phone number (e.g. "+62"), chosen via the phone
  // field's country-code picker (defaults from [_country]).
  String? _phoneDial;

  // Collected session data.
  final Set<String> _skills = {};

  // Personal path (Employment / Education / Other).
  final List<_Employment> _employments = [];
  final List<_Education> _educations = [];
  final List<_Achievement> _achievements = [];
  final Set<String> _hobbies = {};
  final Set<String> _otherIndustries = {};
  final Set<String> _otherProfessions = {};
  final Set<String> _otherCountries = {};

  final OnboardingDraftStore _draftStore = OnboardingDraftStore();

  @override
  void initState() {
    super.initState();
    // Pre-fill from the signed-in account so the identity + registration-type
    // choice (and the backend's work-email check) reflect the real email.
    final user = Session.instance.user;
    final first = (widget.firstName ?? '').trim();
    final fallback = first.isEmpty ? 'Alex' : first;
    final realName = (user?.fullName ?? '').trim();
    final realEmail = (user?.email ?? '').trim();
    _fullName.text = realName.isNotEmpty ? realName : '$fallback Lee';
    _email.text = realEmail.isNotEmpty
        ? realEmail
        : '${fallback.toLowerCase()}.lee@gmail.com';
    // Restore a previously saved draft ("Continue onboarding").
    _loadDraft();
    // Load live masterdata (industries/countries) for the pickers. Until it
    // lands they show a built-in fallback; [_onMasterData] rebuilds on arrival.
    MasterData.instance.addListener(_onMasterData);
    MasterData.instance.ensureLoaded();
  }

  @override
  void dispose() {
    MasterData.instance.removeListener(_onMasterData);
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  // Lets step child-widgets ask the flow to rebuild (e.g. to re-evaluate the
  // action bar's enabled state) without reaching into protected setState.
  void refresh() => setState(() {});

  // Rebuild when live masterdata arrives so the pickers swap fallback → live.
  void _onMasterData() {
    if (mounted) setState(() {});
  }

  // ---- Draft persistence (client-side, keyed by user id) ----------------
  OnboardRole? _roleFromName(String? name) {
    for (final r in OnboardRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }

  Map<String, dynamic> _draftToJson() => {
    'role': (_role ?? _pendingRole)?.name,
    'step': _step,
    'fullName': _fullName.text,
    'email': _email.text,
    'phone': _phone.text,
    'address': _address.text,
    'country': _country,
    'phoneDial': _phoneDial,
    'skills': _skills.toList(),
    'employments': _employments.map(_employmentToJson).toList(),
    'educations': _educations.map(_educationToJson).toList(),
    'achievements': _achievements.map(_achievementToJson).toList(),
    'hobbies': _hobbies.toList(),
    'otherIndustries': _otherIndustries.toList(),
    'otherProfessions': _otherProfessions.toList(),
    'otherCountries': _otherCountries.toList(),
  };

  void _applyDraft(Map<String, dynamic> d) {
    setState(() {
      _role = _roleFromName(d['role'] as String?);
      _pendingRole = _role;
      // Continue always resumes at the first step (with filled fields intact),
      // not wherever the user last left off.
      _step = 0;
      _fullName.text = (d['fullName'] ?? _fullName.text).toString();
      _email.text = (d['email'] ?? _email.text).toString();
      _phone.text = (d['phone'] ?? '').toString();
      _address.text = (d['address'] ?? '').toString();
      _country = d['country'] is String ? d['country'] as String : null;
      _phoneDial = d['phoneDial'] is String ? d['phoneDial'] as String : null;
      _skills
        ..clear()
        ..addAll(_draftStrings(d['skills']));
      _employments
        ..clear()
        ..addAll(_draftList(d['employments']).map(_employmentFromJson));
      _educations
        ..clear()
        ..addAll(_draftList(d['educations']).map(_educationFromJson));
      _achievements
        ..clear()
        ..addAll(_draftList(d['achievements']).map(_achievementFromJson));
      _hobbies
        ..clear()
        ..addAll(_draftStrings(d['hobbies']));
      _otherIndustries
        ..clear()
        ..addAll(_draftStrings(d['otherIndustries']));
      _otherProfessions
        ..clear()
        ..addAll(_draftStrings(d['otherProfessions']));
      _otherCountries
        ..clear()
        ..addAll(_draftStrings(d['otherCountries']));
    });
  }

  void _saveDraft() {
    final uid = Session.instance.user?.id;
    if (uid == null || uid.isEmpty) return;
    // Local "save" half (per-browser resume).
    _draftStore.save(uid, jsonEncode(_draftToJson()));
    // "Sync" half: queue the domain answers for the backend. Identity + the UI
    // resume cursor are dropped — the backend already knows the identity and
    // has no use for the step index.
    SyncEngine.instance.enqueueAnswers(_answersPayload());
  }

  // The onboarding answers document synced to the backend. Drops UI resume
  // state (step) and identity the backend already owns (name/email/address),
  // but KEEPS the country + phone (with the resolved master-data country_id +
  // dial code) and resolves master-data ids alongside every selected name so
  // the answer references the reference rows, not just their labels.
  Map<String, dynamic> _answersPayload() {
    final md = MasterData.instance;
    final country = _country;
    final m = _draftToJson()
      ..remove('step')
      ..remove('fullName')
      ..remove('email')
      ..remove('address');
    // Identity: the person's country + a phone number tied to a dial code
    // (picked via the phone field, defaulting from the country).
    m['country_id'] = country == null ? null : md.countryId(country);
    final dial = _phoneDial?.trim() ?? '';
    final number = _phone.text.trim();
    m['phone_code'] = dial.isEmpty ? null : dial;
    m['phone'] = [dial, number].where((s) => s.isNotEmpty).join(' ');
    // Resolved ids for the flat selections (a custom free-text entry has no id
    // and is skipped).
    m['skill_ids'] = _resolveIds(_skills, md.skillId);
    m['profession_ids'] = _resolveIds(_otherProfessions, md.professionId);
    m['other_industry_ids'] = _resolveIds(_otherIndustries, md.industryId);
    m['other_country_ids'] = _resolveIds(_otherCountries, md.countryId);
    // Per-entry ids for the structured sections.
    m['employments'] = _employments
        .map(
          (e) => {
            ..._employmentToJson(e),
            'industry_id': md.industryId(e.industry),
            'country_id': md.countryId(e.country),
          },
        )
        .toList();
    m['educations'] = _educations
        .map(
          (e) => {
            ..._educationToJson(e),
            'country_id': md.countryId(e.country),
          },
        )
        .toList();
    m['achievements'] = _achievements
        .map(
          (a) => {
            ..._achievementToJson(a),
            'country_id': md.countryId(a.country),
          },
        )
        .toList();
    return m;
  }

  // Resolve the master-data ids for a set of selected names, skipping custom
  // (free-text) entries that have no id.
  List<String> _resolveIds(
    Iterable<String> names,
    String? Function(String) idOf,
  ) {
    final out = <String>[];
    for (final n in names) {
      final id = idOf(n);
      if (id != null) out.add(id);
    }
    return out;
  }

  void _clearDraft() {
    final uid = Session.instance.user?.id;
    if (uid == null || uid.isEmpty) return;
    _draftStore.clear(uid);
  }

  Future<void> _loadDraft() async {
    final uid = Session.instance.user?.id;
    if (uid == null || uid.isEmpty) return;
    final raw = await _draftStore.load(uid);
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) _applyDraft(decoded);
    } catch (_) {
      /* corrupt draft — ignore */
    }
  }

  // ---- Step model -------------------------------------------------------
  // Three content steps: Employment, Education, Other. (Only personal accounts
  // reach onboarding — organizations register and land on the pending screen.)
  int get _totalSteps => 3;

  // Progress spans the identity step + the content steps. Reported to the
  // backend as the user advances so the dashboard can show a completion %.
  int get _totalSections => _totalSteps + 1;
  int _progressPct(int sections) => ((sections / _totalSections) * 100).round();

  // Optional sections that actually have data. Skipping a step does NOT count,
  // so progress reflects real completion rather than pages advanced.
  int get _filledOptionalCount {
    final r = _role;
    if (r == null) return 0;
    var n = 0;
    if (_employments.isNotEmpty || _skills.isNotEmpty) n++;
    if (_educations.isNotEmpty) n++;
    if (_hobbies.isNotEmpty ||
        _achievements.isNotEmpty ||
        _otherIndustries.isNotEmpty ||
        _otherProfessions.isNotEmpty ||
        _otherCountries.isNotEmpty) {
      n++;
    }
    return n;
  }

  // Mandatory step (1) + filled optional sections, as a 0..100 percentage.
  int get _onboardingProgress => _progressPct(1 + _filledOptionalCount);

  // The three step titles.
  ({String title, String subtitle}) get _stepMeta {
    return switch (_step) {
      0 => (
        title: 'Employment',
        subtitle: 'Add any work experience and the skills you have built.',
      ),
      1 => (
        title: 'Education',
        subtitle:
            'Tell us about your formal studies and any other achievements.',
      ),
      _ => (
        title: 'Other',
        subtitle:
            'Optional interests and hobbies that help us tailor your '
            'recommendations.',
      ),
    };
  }

  // Every content step (Employment / Education / Other) is optional.
  bool get _canContinue => true;

  String get _continueLabel =>
      _step == _totalSteps - 1 ? 'Start learning' : 'Continue';

  // ---- Navigation -------------------------------------------------------
  void _pickRole(OnboardRole r) {
    setState(() {
      _role = r;
      _step = 0;
      _forward = true;
    });
  }

  // Leave the identity screen once a name + registration sub-role are set.
  Future<void> _confirmIdentity() async {
    if (_pendingRole == null || _fullName.text.trim().isEmpty) return;

    // Persist the account type for accounts that haven't set it yet (the Google
    // sign-in path — email/password sign-up sets it at registration). Only
    // personal accounts reach onboarding, so the type is always personal.
    if (Session.instance.user?.accountType == null) {
      setState(() {
        _submitting = true;
        _identityError = null;
      });
      try {
        await Session.instance.setAccountType(AccountType.personal);
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _identityError = e.message;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _submitting = false);
    }

    // Guard against the sub-role being cleared while we awaited (defensive —
    // the identity tiles are disabled during submit).
    final role = _pendingRole;
    if (role == null) return;

    // First completion marks the mandatory step (so future logins skip to the
    // dashboard) and seeds the initial progress. A returning user resuming to
    // add optional sections must NOT have their real progress reset to 25% or
    // the mandatory flag re-sent. Best-effort backend call.
    if (!(Session.instance.user?.mandatoryCompleted ?? false)) {
      Session.instance.updateOnboarding(
        progress: _progressPct(1),
        markMandatory: true,
      );
    }
    _pickRole(role);
    _saveDraft();
  }

  Future<void> _next() async {
    if (!_canContinue) return;
    await _advance();
  }

  // Skip the current question, moving on without answering it.
  Future<void> _skipStep() => _advance();

  // Advance to the next step, or finish onboarding when on the last step.
  Future<void> _advance() async {
    // Report progress from sections that actually have data (skipped steps
    // don't count), so an incomplete profile stays < 100%.
    Session.instance.updateOnboarding(progress: _onboardingProgress);
    _saveDraft();
    if (_step < _totalSteps - 1) {
      setState(() {
        _forward = true;
        _step++;
      });
      return;
    }

    // Last step → simulate saving, then show completion.
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _forward = true;
      _step = _totalSteps; // completion screen
    });
  }

  void _back() {
    if (_step == 0) {
      // Back out of the steps to the identity screen, keeping the selection.
      setState(() {
        _forward = false;
        _pendingRole = _role;
        _role = null;
      });
      return;
    }
    setState(() {
      _forward = false;
      _step--;
    });
  }

  // Back on the identity screen: pop if there's somewhere to return to;
  // otherwise this OnboardingFlow is the app's home (a restored, not-yet-
  // onboarded session), so sign out and go to login rather than trapping the
  // user here with no way out (e.g. if confirming keeps being rejected).
  Future<void> _leaveOnboarding() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await Session.instance.signOut();
    if (!mounted) return;
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _goToDashboard() {
    // Keep the draft for a partial profile so "Continue" restores it; a fully
    // complete profile no longer needs one.
    if (_onboardingProgress >= 100) {
      _clearDraft();
    } else {
      _saveDraft();
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardPage(role: _role, firstName: widget.firstName),
      ),
      (route) => false,
    );
  }

  // Skip the whole onboarding — confirm first, then jump to the dashboard.
  Future<void> _skipOnboarding() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (_) => const _SkipDialog(),
    );
    if (skip == true && mounted) _goToDashboard();
  }

  // ---- Build ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final onIdentity = _role == null;
    final Widget body;
    if (onIdentity) {
      body = _WhoYouAreStep(key: const ValueKey('identity'), state: this);
    } else if (_step >= _totalSteps) {
      body = _CompleteScreen(
        key: const ValueKey('done'),
        firstName: widget.firstName,
        onContinue: _goToDashboard,
      );
    } else {
      body = _StepBody(
        key: ValueKey('step-$_step'),
        role: _role!,
        step: _step,
        state: this,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              showProgress: _role != null && _step < _totalSteps,
              step: _step,
              totalSteps: _totalSteps,
              onBack: _role == null
                  ? _leaveOnboarding
                  : (_step < _totalSteps ? _back : null),
              // The identity ("Let's get to know you") screen is mandatory, so
              // no skip there; skipping is only offered on the later steps.
              onSkip: (!onIdentity && _step < _totalSteps && !_submitting)
                  ? _skipOnboarding
                  : null,
            ),
            Expanded(
              child: _Transitioner(
                forward: _forward,
                reduceMotion: _reduceMotion(context),
                child: body,
              ),
            ),
            if (onIdentity || _step < _totalSteps)
              _ActionBar(
                onBack: _back,
                onContinue: onIdentity
                    ? ((_pendingRole != null &&
                              _fullName.text.trim().isNotEmpty &&
                              !_submitting)
                          ? _confirmIdentity
                          : null)
                    : (_canContinue && !_submitting ? _next : null),
                onSkipStep: (onIdentity || _submitting) ? null : _skipStep,
                continueLabel: onIdentity ? 'Continue' : _continueLabel,
                busy: _submitting,
                showBack: !onIdentity,
              ),
          ],
        ),
      ),
    );
  }
}
