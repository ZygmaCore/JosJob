part of '../landing_page_ascent.dart';

// daisyUI skill patterns: navbar, hero, browser mockup, cards, steps and footer.
// This application renders Flutter widgets; its shared theme supplies the tokens.
class JosjobLandingPage extends StatefulWidget {
  const JosjobLandingPage({super.key});
  @override
  State<JosjobLandingPage> createState() => _JosjobLandingPageState();
}

class _JosjobLandingPageState extends State<JosjobLandingPage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  String get _accountRoute =>
      Session.instance.isSignedIn ? '/dashboard' : '/register';
  String get _accountLabel => Session.instance.isSignedIn
      ? 'Open your workspace'
      : 'Create your account';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchJobs([String? value]) {
    final query = (value ?? _search.text).trim();
    FocusScope.of(context).unfocus();
    _go(
      Uri(
        path: '/jobs',
        queryParameters: query.isEmpty ? null : {'q': query},
      ).toString(),
    );
  }

  final _journeyKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _jump(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: _anim(context, 400),
        alignment: 0.03,
      );
    }
  }

  void _go(String route) => Navigator.of(context).pushNamed(route);
  TextStyle _text(
    double size, {
    Color color = AppColors.navy,
    FontWeight weight = FontWeight.w400,
    double height = 1.55,
  }) => GoogleFonts.poppins(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );

  Widget _title(
    String value, {
    double size = 36,
    Color color = AppColors.navy,
  }) => Semantics(
    header: true,
    child: Text(
      value,
      style: _text(
        size,
        color: color,
        weight: FontWeight.w600,
        height: 1.2,
      ).copyWith(letterSpacing: -1),
    ),
  );
  Widget _kicker(String value) => Text(
    value,
    style: _text(
      11,
      color: AppColors.brandBlue,
      weight: FontWeight.w600,
    ).copyWith(letterSpacing: 1.8),
  );
  Widget _body(String value, {double size = 15}) =>
      Text(value, style: _text(size, color: AppColors.body));
  Widget _badge(
    String label, {
    Color tint = AppColors.tintBlue,
    Color foreground = AppColors.brandBlue,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: _text(10, color: foreground, weight: FontWeight.w600),
    ),
  );
  Widget _icon(IconData icon, Color color, Color tint, {double size = 44}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      );
  Widget _section(
    Widget child, {
    Color color = Colors.white,
    double? vertical,
  }) => ColoredBox(
    color: color,
    child: _Bounded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: vertical ?? (_isMobile(context) ? 48 : 76),
        ),
        child: child,
      ),
    ),
  );

  Widget _navigation() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: _Bounded(
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            const AppBrand(size: 34),
            const Spacer(),
            if (MediaQuery.sizeOf(context).width >= 900) ...[
              TextButton(
                key: const ValueKey('landing-nav-jobs'),
                onPressed: () => _go('/jobs'),
                child: const Text('Explore jobs'),
              ),
              TextButton(
                key: const ValueKey('landing-nav-journey'),
                onPressed: () => _jump(_journeyKey),
                child: const Text('How it works'),
              ),
              TextButton(
                key: const ValueKey('landing-nav-faq'),
                onPressed: () => _jump(_faqKey),
                child: const Text('FAQ'),
              ),
              const SizedBox(width: 24),
            ],
            OutlinedButton(
              key: const ValueKey('landing-login'),
              onPressed: () =>
                  _go(Session.instance.isSignedIn ? '/dashboard' : '/login'),
              child: Text(Session.instance.isSignedIn ? 'Dashboard' : 'Log in'),
            ),
            if (MediaQuery.sizeOf(context).width < 900) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('landing-menu'),
                tooltip: 'Open menu',
                onPressed: () => _scaffold.currentState!.openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _drawer() => Drawer(
    backgroundColor: Colors.white,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppBrand(),
                const Spacer(),
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 28),
            for (final entry in [
              ('Explore jobs', Icons.work_outline, () => _go('/jobs')),
              ('How it works', Icons.route_outlined, () => _jump(_journeyKey)),
              ('FAQ', Icons.help_outline, () => _jump(_faqKey)),
            ])
              ListTile(
                leading: Icon(entry.$2),
                title: Text(entry.$1),
                onTap: () {
                  Navigator.of(context).pop();
                  entry.$3();
                },
              ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _go(_accountRoute);
              },
              child: Text(_accountLabel),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _hero() => _section(
    LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.brandBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    'YOUR AMBITION HAS A PLACE HERE',
                    style: _text(
                      10,
                      color: AppColors.brandBlue,
                      weight: FontWeight.w600,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedCareerHeadline(
              style: _text(
                wide ? 56 : (_isMobile(context) ? 41 : 56),
                weight: FontWeight.w600,
                height: 1.14,
              ).copyWith(letterSpacing: -2),
            ),
            const SizedBox(height: 22),
            _body(
              'Find your first role. Build skills that matter. Get a little guidance along the way. Your next chapter starts with a place to begin.',
              size: wide ? 16 : 15,
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppColors.rule2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: .05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('landing-job-search'),
                      controller: _search,
                      onSubmitted: _searchJobs,
                      textInputAction: TextInputAction.search,
                      style: _text(13),
                      decoration: const InputDecoration(
                        hintText: 'Job title, skill or keyword',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.body,
                        ),
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    key: const ValueKey('landing-search-submit'),
                    tooltip: 'Search jobs',
                    onPressed: _searchJobs,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const ValueKey('landing-start'),
                  onPressed: () => _go(_accountRoute),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start your journey'),
                      SizedBox(width: 10),
                      Icon(Icons.north_east, size: 17),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('landing-explore-jobs'),
                  onPressed: () => _go('/jobs'),
                  child: const Text('Explore jobs'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _body(
                    'No account needed to explore jobs. Your next step is yours to choose.',
                    size: 12,
                  ),
                ),
              ],
            ),
          ],
        );
        final preview = _LandingProductPreview(onOpen: _go);
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 44),
                  Expanded(child: preview),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 36), preview],
              );
      },
    ),
    color: const Color(0xFFF8FAFD),
    vertical: _isMobile(context) ? 34 : 58,
  );

  Widget _benefits() => _section(
    Wrap(
      spacing: 32,
      runSpacing: 18,
      alignment: WrapAlignment.spaceBetween,
      children: [
        for (final (icon, title, body) in [
          (
            Icons.public_outlined,
            'Explore freely',
            'Public job listings. No account needed.',
          ),
          (
            Icons.auto_stories_outlined,
            'Make learning count',
            'Practical skills for your next direction.',
          ),
          (
            Icons.chat_bubble_outline,
            'Keep the conversation going',
            'Hiring and coaching chats in one place.',
          ),
        ])
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 768
                ? double.infinity
                : 290,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.brandBlue, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _text(13, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      _body(body, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    vertical: 28,
  );

  Widget _features() => _section(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kicker('YOUR NEXT MOVE, CONNECTED'),
        const SizedBox(height: 14),
        _title(
          'Less switching tabs.\nMore moving forward.',
          size: _isMobile(context) ? 30 : 38,
        ),
        const SizedBox(height: 14),
        _body(
          'A place for the opportunity, the skills, and the conversations that get you closer.',
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 850;
            final jobs = _featureCard(
              '01 / OPPORTUNITIES',
              'Find work worth\nshowing up for.',
              'Browse vacancies, see what employers need, and keep track of every step after you apply.',
              Icons.work_outline,
              'Explore jobs',
              () => _go('/jobs'),
              large: true,
            );
            final learning = _featureCard(
              '02 / LEARNING',
              'Build skills with a purpose.',
              'Explore courses and classes as you work towards your next direction.',
              Icons.auto_stories_outlined,
              'Explore learning',
              () => _go('/explore'),
            );
            final coaching = _featureCard(
              '03 / COACHING',
              'A conversation can open a door.',
              'Find a coach, book a free appointment, and keep the conversation in one place.',
              Icons.forum_outlined,
              'Find a coach',
              () => _go('/coaching'),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: jobs),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            learning,
                            const SizedBox(height: 20),
                            coaching,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      jobs,
                      const SizedBox(height: 16),
                      learning,
                      const SizedBox(height: 16),
                      coaching,
                    ],
                  );
          },
        ),
      ],
    ),
    color: AppColors.bg,
  );

  Widget _featureCard(
    String category,
    String title,
    String description,
    IconData icon,
    String action,
    VoidCallback onTap, {
    bool large = false,
  }) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: _HoverLift(
      cursor: SystemMouseCursors.basic,
      builder: (hovered) => AnimatedContainer(
        duration: _anim(context, 180),
        width: double.infinity,
        padding: EdgeInsets.all(_isMobile(context) ? 24 : 28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hovered ? AppColors.rule2 : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: .04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _icon(
                  icon,
                  category.startsWith('02')
                      ? const Color(0xFF9B6221)
                      : category.startsWith('03')
                      ? AppColors.success
                      : AppColors.brandBlue,
                  category.startsWith('02')
                      ? AppColors.tintOrange
                      : category.startsWith('03')
                      ? AppColors.tintGreen
                      : AppColors.tintBlue,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    category,
                    style: _text(
                      10,
                      color: AppColors.body,
                      weight: FontWeight.w500,
                    ).copyWith(letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _title(title, size: large ? (_isMobile(context) ? 28 : 34) : 22),
            const SizedBox(height: 12),
            _body(description, size: 14),
            if (large) ...[
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A clear path from application to offer',
                      style: _text(12, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    for (final (index, label) in [
                      'Applied',
                      'Reviewing',
                      'Interview',
                      'Offer',
                      'Hired',
                    ].indexed)
                      Padding(
                        padding: EdgeInsets.only(bottom: index == 4 ? 0 : 14),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0
                                    ? AppColors.tintBlue
                                    : Colors.white,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(
                                index == 0
                                    ? Icons.check
                                    : Icons.circle_outlined,
                                size: 12,
                                color: index == 0
                                    ? AppColors.brandBlue
                                    : AppColors.rule2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: _text(
                                  12,
                                  color: index == 0
                                      ? AppColors.brandBlue
                                      : AppColors.body,
                                ),
                              ),
                            ),
                            if (index == 0) _badge('Your starting point'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextButton(
              onPressed: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 17),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _journey() => _section(
    Column(
      key: _journeyKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kicker('A FIRST STEP. THEN THE NEXT.'),
        const SizedBox(height: 14),
        _title(
          'You don’t need it all figured out.',
          size: _isMobile(context) ? 30 : 38,
        ),
        const SizedBox(height: 14),
        _body('Start where you are. Move forward one step at a time.'),
        const SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 800;
            final steps = [
              (
                'Discover your direction',
                'Explore roles and their requirements. Find an opportunity that makes you want to take the next step.',
              ),
              (
                'Bring your story together',
                'Build your profile, add your skills and qualifications, and choose the CV you want to share.',
              ),
              (
                'Apply. Talk. Keep moving.',
                'Apply to a role, follow its progress, and chat with the hiring team. Build skills and seek coaching along the way.',
              ),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, step) in steps.indexed)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == 2 ? 0 : 24,
                            ),
                            child: _journeyStep(index, step, wide: true),
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      for (final (index, step) in steps.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _journeyStep(index, step),
                        ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 22,
                color: AppColors.brandBlue,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Your CV. Your next step.',
                          style: _text(14, weight: FontWeight.w500),
                        ),
                        _badge(
                          'CV MATCHING',
                          tint: AppColors.paper2,
                          foreground: AppColors.body,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _body(
                      'Upload your CV, review your skills, and find relevant jobs. See skills to build and explore matching courses before you apply.',
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _journeyStep(int index, (String, String) step, {bool wide = false}) {
    final circle = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '0${index + 1}',
        style: _text(13, color: AppColors.brandBlue, weight: FontWeight.w600),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.$1, style: _text(17, weight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 10),
        _body(step.$2, size: 13),
      ],
    );
    return wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  circle,
                  const SizedBox(width: 14),
                  if (index < 2)
                    Expanded(
                      child: Container(height: 1, color: AppColors.border),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              copy,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              circle,
              const SizedBox(width: 16),
              Expanded(child: copy),
            ],
          );
  }

  Widget _faq() => _section(
    LayoutBuilder(
      key: _faqKey,
      builder: (context, c) {
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('GOOD QUESTIONS. CLEAR ANSWERS.'),
            const SizedBox(height: 14),
            _title(
              'A little clarity\ngoes a long way.',
              size: _isMobile(context) ? 30 : 36,
            ),
            const SizedBox(height: 14),
            _body(
              'A few things to know before your next career move.',
              size: 14,
            ),
          ],
        );
        final answers = Column(
          children: [
            for (final (index, entry) in [
              (
                'Who is JosJob for?',
                'Fresh graduates, final-year students and anyone building skills towards their next job in Indonesia. Employers and educators are part of the community, too.',
              ),
              (
                'Do I need an account to browse jobs?',
                'No. You can browse active job listings and open their details without signing in. Create an account when you’re ready to apply and track your applications.',
              ),
              (
                'Is JosJob free?',
                'Job access is free for graduates, and coaching appointments are currently free. Courses and classes may have separate fees; check the price before enrolling.',
              ),
              (
                'How does CV matching work?',
                'Sign in and upload a PDF CV from Jobs. Review the extracted skills before saving. Jobs are ordered by category, skill overlap and recency; you can explore learning suggestions when you apply.',
              ),
              (
                'Does JosJob guarantee a job?',
                'No. Hiring decisions remain with employers. JosJob helps you explore opportunities, build skills and have useful conversations; completing a course does not guarantee employment.',
              ),
            ].indexed)
              _FaqItem('Q${index + 1}', entry, initiallyOpen: index == 0),
          ],
        );
        return c.maxWidth >= 850
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: intro),
                  const SizedBox(width: 64),
                  Expanded(flex: 6, child: answers),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [intro, const SizedBox(height: 28), answers],
              );
      },
    ),
    color: AppColors.bg,
  );

  Widget _closing() => _section(
    Container(
      padding: EdgeInsets.all(_isMobile(context) ? 28 : 48),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR NEXT CHAPTER',
                style: _text(
                  10,
                  color: AppColors.onNavyDim,
                  weight: FontWeight.w600,
                ).copyWith(letterSpacing: 1.7),
              ),
              const SizedBox(height: 16),
              _title(
                'A first step can\nchange your direction.',
                size: _isMobile(context) ? 29 : 36,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              Text(
                'Bring your ambition. We’ll help you find a place to start.',
                style: _text(13, color: AppColors.onNavyDim),
              ),
            ],
          );
          final action = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PillButton(
                _accountLabel,
                kind: _BtnKind.white,
                onPressed: () => _go(_accountRoute),
                trailing: Icons.arrow_forward,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _go('/jobs'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Explore jobs first'),
              ),
            ],
          );
          return c.maxWidth >= 800
              ? Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 32),
                    action,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 26), action],
                );
        },
      ),
    ),
  );

  Widget _footer() => _section(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 48,
          runSpacing: 28,
          children: [
            SizedBox(
              width: 330,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppBrand(),
                  const SizedBox(height: 14),
                  _body(
                    'Job discovery, learning and coaching.\nBuilt for your next move in Indonesia.',
                    size: 12,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => _go('/jobs'),
                  child: const Text('Jobs'),
                ),
                TextButton(
                  onPressed: () => _go('/explore'),
                  child: const Text('Learning'),
                ),
                TextButton(
                  onPressed: () => _go('/coaching'),
                  child: const Text('Coaching'),
                ),
                TextButton(
                  onPressed: () => _jump(_faqKey),
                  child: const Text('FAQ'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Divider(height: 1),
        const SizedBox(height: 20),
        _body(
          '© ${DateTime.now().year} JosJob. Your progress. Your pace.',
          size: 11,
        ),
      ],
    ),
    vertical: 28,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffold,
    backgroundColor: Colors.white,
    endDrawer: _drawer(),
    body: Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              _navigation(),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('landing-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(),
                      _benefits(),
                      _features(),
                      _journey(),
                      _faq(),
                      _closing(),
                      _footer(),
                    ],
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
