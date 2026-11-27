part of '../dashboard_page.dart';

const _careerNav = <_NavDest>[
  _NavDest('Home', Icons.home_outlined),
  _NavDest('Jobs', Icons.work_outline),
  _NavDest('My applications', Icons.description_outlined),
  _NavDest('Learning', Icons.menu_book_outlined),
  _NavDest('Coaching', Icons.people_outline),
  _NavDest('Profile & CV', Icons.person_outline),
];

class _CareerShell extends StatefulWidget {
  final String? firstName;
  final String initialView, initialTab, applicationScope, applicationStatus;
  const _CareerShell({
    this.firstName,
    required this.initialView,
    required this.initialTab,
    required this.applicationScope,
    required this.applicationStatus,
  });
  @override
  State<_CareerShell> createState() => _CareerShellState();
}

class _CareerShellState extends State<_CareerShell> {
  final _contentKey = GlobalKey();
  final _scroll = ScrollController();
  late final String _tab = _resolveTab();
  String _resolveTab() {
    final tab = widget.initialTab;
    if (widget.initialView == 'career') {
      return {
            'home',
            'jobs',
            'applications',
            'learning',
            'learning-catalog',
            'profile',
            'profile-certificates',
            'coaching',
          }.contains(tab)
          ? tab
          : 'home';
    }
    if (widget.initialView == 'jobs') {
      return switch (tab) {
        'vacancies' => 'jobs',
        'applications' => 'applications',
        'curriculum-vitae' => 'profile',
        _ => 'home',
      };
    }
    return switch (tab) {
      'courses' => 'learning-catalog',
      'my-courses' => 'learning',
      'certificates' => 'profile-certificates',
      'live-coaching' => 'coaching',
      _ => 'home',
    };
  }

  int get _index => switch (_tab) {
    'jobs' => 1,
    'applications' => 2,
    'learning' || 'learning-catalog' => 3,
    'coaching' => 4,
    'profile' || 'profile-certificates' => 5,
    _ => 0,
  };
  String get _name =>
      widget.firstName ?? Session.instance.user?.firstName ?? 'there';
  Future<void> _go(String tab) async {
    if (tab == _tab) return;
    await Navigator.of(context).pushNamed(
      Uri(
        path: '/dashboard',
        queryParameters: {'view': 'career', 'tab': tab},
      ).toString(),
    );
  }

  void _select(int index) => _go(
    ['home', 'jobs', 'applications', 'learning', 'coaching', 'profile'][index],
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _tabs(List<(String, String)> tabs) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (tab, label) in tabs)
          ChoiceChip(
            key: ValueKey('career-section-$tab'),
            label: Text(label),
            selected: _tab == tab,
            onSelected: (_) => _go(tab),
          ),
      ],
    ),
  );
  Widget _content() => switch (_index) {
    0 => _CareerHome(name: _name, go: _go),
    1 => const _VacanciesScreen(),
    2 => _JobApplicationsScreen(
      hiring: widget.applicationScope == 'hiring',
      initialStatus: widget.applicationStatus,
      onLocationChanged: (scope, status) => Navigator.of(context).pushNamed(
        Uri(
          path: '/dashboard',
          queryParameters: {
            'view': 'career',
            'tab': 'applications',
            'scope': scope,
            if (status.isNotEmpty) 'status': status,
          },
        ).toString(),
      ),
    ),
    3 => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs([
          ('learning', 'My learning'),
          ('learning-catalog', 'Course catalog'),
        ]),
        if (_tab == 'learning-catalog')
          const ExploreCoursesView()
        else
          const _MyCoursesScreen(),
      ],
    ),
    4 => const LiveCoachingView(),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs([
          ('profile', 'CV & skills'),
          ('profile-certificates', 'Certificates'),
        ]),
        if (_tab == 'profile-certificates')
          const CertificatesView()
        else ...[
          CurriculumVitaeView(
            onManageCertificates: () => _go('profile-certificates'),
          ),
          const SizedBox(height: 24),
          Text('Account tools', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _documents(context),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Manage documents'),
              ),
              TextButton.icon(
                key: const ValueKey('open-coach-workspace'),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/coaching/workspace'),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Coach workspace'),
              ),
            ],
          ),
        ],
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Bp.desktop;
    final body = SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.all(wide ? 32 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Bp.maxContent),
          child: KeyedSubtree(key: _contentKey, child: _content()),
        ),
      ),
    );
    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(
          children: [
            _Sidebar(
              dests: _careerNav,
              currentIndex: _index,
              onSelect: _select,
              name: _name,
              role: null,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: _careerNav[_index].label,
                    mobile: false,
                    showDocuments: false,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }
    const indices = [1, 2, 3, 5];
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: _MobileDrawer(
        dests: _careerNav,
        currentIndex: _index,
        onSelect: _select,
        name: _name,
        role: null,
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Builder(
          builder: (context) => _TopBar(
            title: _careerNav[_index].label,
            mobile: true,
            showDocuments: false,
            onMenu: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: _BottomNav(
        dests: [for (final i in indices) _careerNav[i]],
        currentIndex: indices.indexOf(_index),
        onSelect: (i) => _select(indices[i]),
      ),
    );
  }
}

class _CareerHome extends StatefulWidget {
  final String name;
  final Future<void> Function(String) go;
  const _CareerHome({required this.name, required this.go});
  @override
  State<_CareerHome> createState() => _CareerHomeState();
}

class _CareerHomeState extends State<_CareerHome> {
  final _api = StudyApi();
  late Future<List<Map<String, dynamic>>> _studies = Session.instance.runAuthed(
    _api.mine,
  );
  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      JobsOverviewView(
        firstName: widget.name,
        onBrowseJobs: () => widget.go('jobs'),
        onEditProfile: () => widget.go('profile'),
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              'Continue learning',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: () => widget.go('learning'),
            child: const Text('My learning'),
          ),
        ],
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _studies,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(
                () => _studies = Session.instance.runAuthed(_api.mine),
              ),
              child: const Text('Retry learning progress'),
            );
          }
          final studies = (snapshot.data ?? [])
              .where((study) => study['progress'] != 100)
              .take(3)
              .toList();
          if (studies.isEmpty) {
            return Card(
              child: ListTile(
                title: const Text('Build skills for your next role'),
                subtitle: const Text(
                  'Find a course from a job skill gap or browse the course catalog.',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => widget.go('learning-catalog'),
              ),
            );
          }
          return Column(
            children: [
              for (final study in studies)
                Card(
                  child: ListTile(
                    title: Text(study['title'] as String),
                    subtitle: Text("${study['progress']}% complete"),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/learn/${study['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
