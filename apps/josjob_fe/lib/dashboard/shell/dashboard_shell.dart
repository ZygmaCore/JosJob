part of '../dashboard_page.dart';

// =========================================================================
// Responsive shell that hosts the nav + content. Nav selection is in-memory
// (int index). Desktop: sidebar + top bar + scroll body. Mobile: top bar +
// scroll body + bottom nav (with a drawer for the same destinations).
// =========================================================================
class _DashboardShell extends StatefulWidget {
  final OnboardRole? role;
  final String? firstName;
  const _DashboardShell({required this.role, required this.firstName});

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  int _index = 0;
  _DashView _view = _DashView.learn;

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  // Flip the whole dashboard between the Learn and Jobs products. Resets the
  // nav selection so a destination from the other view isn't left highlighted.
  void _setView(_DashView v) {
    if (v == _view) return;
    setState(() {
      _view = v;
      _index = 0;
    });
  }

  // Prefer the name passed from onboarding; otherwise fall back to the
  // signed-in session user (after login / Google / a restored session).
  String? get _firstName {
    final passed = (widget.firstName ?? '').trim();
    if (passed.isNotEmpty) return passed;
    final fn = (Session.instance.user?.firstName ?? '').trim();
    return fn.isEmpty ? null : fn;
  }

  String get _name => _firstName ?? 'there';

  // Resume onboarding (optional sections) from the dashboard progress card.
  void _continueOnboarding() => Navigator.of(context).pushNamed('/onboarding');

  // Onboarding hands over the exact sub-role once (on first completion); every
  // other entry — login, Google, a page reload — constructs the dashboard with
  // role == null. Fall back to the persisted account type so returning
  // organization users get the org view instead of the individual learner view.
  OnboardRole? get _effectiveRole {
    final passed = widget.role;
    if (passed != null) return passed;
    return switch (Session.instance.user?.accountType) {
      AccountType.organization => OnboardRole.employer,
      _ => null,
    };
  }

  // Data bundle for the active product view. Jobs is role-agnostic; Learn
  // stays role-adaptive (individual vs org).
  _DashboardData get _data =>
      _view == _DashView.jobs ? _jobsData : _dataFor(_effectiveRole);

  int _navIndexOf(_DashboardData data, String label) {
    final i = data.nav.indexWhere((d) => d.label == label);
    return i < 0 ? _index : i;
  }

  // Index 0 is the overview. Every other destination routes to a real screen
  // per active view / role; the placeholder panel is a defensive fallback.
  Widget _content(_DashboardData data) {
    if (_index == 0) {
      final Widget overview = _view == _DashView.jobs
          ? _OverviewJobs(data: data, firstName: _firstName)
          : isOrg(_effectiveRole)
          ? _OverviewOrg(data: data, firstName: _firstName)
          : _OverviewIndividual(
              data: data,
              firstName: _firstName,
              onBrowseCourses: () => _select(_navIndexOf(data, 'Courses')),
            );

      // Nudge to finish onboarding when the mandatory step is done but the
      // optional sections aren't (progress < 100).
      final user = Session.instance.user;
      if (user != null &&
          user.mandatoryCompleted &&
          user.onboardingProgress < 100) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OnboardingProgressCard(
              progress: user.onboardingProgress,
              onContinue: _continueOnboarding,
            ),
            const SizedBox(height: 24),
            overview,
          ],
        );
      }
      return overview;
    }
    final label = data.nav[_index].label;
    if (_view == _DashView.jobs) {
      switch (label) {
        case 'Vacancies':
          return const _VacanciesScreen();
        case 'Curriculum Vitae':
          return const _CvScreen();
        case 'Applications':
          return const _JobApplicationsScreen();
      }
    } else if (isOrg(_effectiveRole)) {
      switch (label) {
        case 'My Team':
          return const _MyTeamScreen(_teamRoster);
        case 'Training':
          return const _TrainingScreen(_trainingCatalog);
        case 'Live Coaching':
          return const _LiveCoachingScreen();
        case 'Reports':
          return _ReportsScreen(data);
      }
    } else {
      switch (label) {
        case 'Courses':
          return const ExploreCoursesView();
        case 'My Courses':
          return const _MyCoursesScreen();
        case 'Live Coaching':
          return const _LiveCoachingScreen();
        case 'Certificates':
          return _CertificatesScreen(data.certificates);
      }
    }
    return _PlaceholderPanel(data.nav[_index], view: _view);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final wide = MediaQuery.sizeOf(context).width >= Bp.desktop;
    return wide ? _buildDesktop(context, data) : _buildMobile(context, data);
  }

  // ---- Desktop ----------------------------------------------------------
  Widget _buildDesktop(BuildContext context, _DashboardData data) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w >= 1440 ? 40.0 : 28.0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _Sidebar(
            dests: data.nav,
            currentIndex: _index,
            onSelect: _select,
            name: _name,
            role: _effectiveRole,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: data.nav[_index].label, mobile: false),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Bp.maxContent,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _ViewSwitcher(
                                current: _view,
                                onChanged: _setView,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _content(data),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Mobile -----------------------------------------------------------
  Widget _buildMobile(BuildContext context, _DashboardData data) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: _MobileDrawer(
        dests: data.nav,
        currentIndex: _index,
        onSelect: _select,
        name: _name,
        role: _effectiveRole,
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Builder(
          builder: (context) => _TopBar(
            title: data.nav[_index].label,
            mobile: true,
            onMenu: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _ViewSwitcher(current: _view, onChanged: _setView),
            ),
            const SizedBox(height: 20),
            _content(data),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        dests: data.nav,
        currentIndex: _index,
        onSelect: _select,
      ),
    );
  }
}

// Human-readable role label for the user card / drawer.
String _roleLabel(OnboardRole? r) => switch (r) {
  OnboardRole.employer => 'Employer',
  OnboardRole.coordinator => 'Coordinator',
  OnboardRole.worker => 'Individual Worker',
  OnboardRole.graduate => 'Graduate',
  null => 'Learner',
};
