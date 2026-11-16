part of '../landing_page_ascent.dart';

class StellarLandingPage extends StatefulWidget {
  const StellarLandingPage({super.key});

  @override
  State<StellarLandingPage> createState() => _StellarLandingPageState();
}

class _StellarLandingPageState extends State<StellarLandingPage> {
  final _journeyKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _jump(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: _anim(context, 400),
        alignment: 0.04,
      );
    }
  }

  void _register() => Navigator.of(context).pushNamed('/register');

  Widget _heading(String label, String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Eyebrow(label),
      const SizedBox(height: 16),
      Semantics(header: true, child: Text(title, style: _h2s(context))),
      const SizedBox(height: 18),
      Text(body, style: _lead(context)),
    ],
  );

  Widget _section(Widget child, {Color color = Colors.white}) => ColoredBox(
    color: color,
    child: _Bounded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _isMobile(context) ? 48 : 80),
        child: child,
      ),
    ),
  );

  Widget _cards(List<(String, String, IconData)> items) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: _HoverLift(
                builder: (hovered) => Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, color: AppColors.brandBlue, size: 30),
                      const SizedBox(height: 22),
                      Semantics(
                        header: true,
                        child: Text(
                          item.$1,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.$2,
                        style: _lead(context).copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final heroCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('YOUR NEXT CHAPTER STARTS HERE'),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            'Your degree is a start.\nBuild what comes next.',
            style: _display(context, color: AppColors.navy),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Find your direction. Build the skills. Move closer to your dream job.',
          style: _lead(
            context,
            color: AppColors.navy,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'JosJob brings job discovery and online learning together for fresh graduates, final-year students and career builders in Indonesia. Start with opportunities and courses today, and discover our vision for AI-powered CV matching.',
          style: _lead(context),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PillButton(
              'Start your journey',
              onPressed: _register,
              trailing: Icons.arrow_forward,
            ),
            _PillButton(
              'See how it works',
              kind: _BtnKind.ghost,
              onPressed: () => _jump(_journeyKey),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Free job access for graduates. Course pricing varies.',
          style: _lead(context).copyWith(fontSize: 13),
        ),
      ],
    );
    final preview = Container(
      padding: EdgeInsets.all(mobile ? 24 : 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.08),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('THE JOSJOB VISION'),
          const SizedBox(height: 20),
          Text('Less guesswork.\nA clearer next step.', style: _h2s(context)),
          const SizedBox(height: 24),
          for (final step in [
            ('01', 'Match', 'Discover roles that fit your profile.'),
            ('02', 'Find the gap', 'Understand which skills need attention.'),
            ('03', 'Learn', 'Build skills with relevant learning paths.'),
            ('04', 'Match again', 'Revisit your fit as your skills grow.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.tintBlue,
                    child: Text(
                      step.$1,
                      style: const TextStyle(color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          step.$3,
                          style: _lead(context).copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'AI matching and connected learning paths are planned features.',
            style: _lead(context).copyWith(fontSize: 13),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Bounded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: SvgPicture.asset(
                          'assets/branding/josjob-logo.svg',
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          'JosJob',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!mobile) ...[
                        TextButton(
                          onPressed: () => _jump(_journeyKey),
                          child: const Text('How it works'),
                        ),
                        TextButton(
                          onPressed: () => _jump(_faqKey),
                          child: const Text('FAQ'),
                        ),
                        const SizedBox(width: 16),
                      ],
                      _PillButton(
                        'Log in',
                        kind: _BtnKind.ghost,
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/login'),
                      ),
                    ],
                  ),
                ),
              ),
              _section(
                mobile
                    ? Column(
                        children: [
                          heroCopy,
                          const SizedBox(height: 36),
                          preview,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 6, child: heroCopy),
                          const SizedBox(width: 56),
                          Expanded(flex: 5, child: preview),
                        ],
                      ),
                color: AppColors.tintBlue,
              ),
              _section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'FROM SEARCHING TO A SENSE OF DIRECTION',
                      'You have ambition. You need a way forward.',
                      'Scattered job listings. Unclear skill requirements. Courses that feel disconnected from your goals. Your first career move should come with a clearer plan.',
                    ),
                    const SizedBox(height: 32),
                    _cards([
                      (
                        'Find a starting point',
                        'Explore job opportunities and discover what employers are looking for, even when you are still deciding on a direction.',
                        Icons.explore_outlined,
                      ),
                      (
                        'Make learning count',
                        'Build practical skills through courses, videos, classes and live sessions instead of collecting learning without a goal.',
                        Icons.school_outlined,
                      ),
                      (
                        'Connect the next steps',
                        'Our goal is one connected journey from your CV to role fit, skill gaps and learning, so every step has a purpose.',
                        Icons.route_outlined,
                      ),
                    ]),
                  ],
                ),
              ),
              _section(
                Column(
                  key: _journeyKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'HOW JOSJOB IS DESIGNED TO WORK',
                      'One journey. Five purposeful steps.',
                      'A career platform built around progress, with AI CV analysis and matching on the roadmap.',
                    ),
                    const SizedBox(height: 32),
                    _cards([
                      (
                        '01 / Tell your story',
                        'Build a profile around your education, skills, interests and preferred industries. CV upload and AI extraction are planned to make this easier.',
                        Icons.person_outline,
                      ),
                      (
                        '02 / Discover your fit',
                        'Planned AI matching will rank companies and roles by profile fit, with a match score and a short explanation of the result.',
                        Icons.work_outline,
                      ),
                      (
                        '03 / See the skill gaps',
                        'Understand the skills a role asks for and where you can grow. Missing-skill explanations are part of the planned matching experience.',
                        Icons.manage_search_outlined,
                      ),
                      (
                        '04 / Learn with purpose',
                        'Explore courses and classes today. Planned learning paths will connect missing skills to relevant videos, courses and live sessions.',
                        Icons.auto_stories_outlined,
                      ),
                      (
                        '05 / Re-match and apply',
                        'The planned re-match flow will let you revisit role rankings after learning, then continue to the original job listing to apply.',
                        Icons.trending_up,
                      ),
                    ]),
                  ],
                ),
                color: AppColors.tintBlue,
              ),
              _section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'BUILT AROUND YOUR NEXT MOVE',
                      'Your starting point is welcome here.',
                      'Whether you are looking for a first job or a fresh direction, start with the skills and experience you have.',
                    ),
                    const SizedBox(height: 32),
                    _cards([
                      (
                        'Fresh graduates',
                        'Turn your education into a practical career direction. Explore entry-level opportunities and build skills for the roles you want.',
                        Icons.school_outlined,
                      ),
                      (
                        'Final-year students',
                        'Start before graduation. Discover role requirements and make your remaining study time count toward your first career move.',
                        Icons.menu_book_outlined,
                      ),
                      (
                        'Career builders',
                        'Ready to upskill or change direction? Explore learning opportunities that help you work toward your next role.',
                        Icons.stairs_outlined,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    Text(
                      'For employers and educators',
                      style: _h2s(context).copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Employers can publish job opportunities through an employer account. Instructors and institutions bring courses and classes to the learning experience. Together, these are the foundation for connecting learning to hiring needs.',
                      style: _lead(context),
                    ),
                  ],
                ),
              ),
              _section(
                Column(
                  key: _faqKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'BEFORE YOU GET STARTED',
                      'A little clarity goes a long way.',
                      'Answers for your next career step.',
                    ),
                    const SizedBox(height: 24),
                    for (final entry in [
                      (
                        'Who is JosJob for?',
                        'JosJob is for fresh graduates, final-year students and anyone building skills toward their next job in Indonesia. Employers, instructors and institutions also have a place on the platform.',
                      ),
                      (
                        'How is JosJob different from a job portal?',
                        'JosJob brings job discovery and learning into one platform. Our planned AI experience will connect profile fit, missing skills, learning paths and re-matching rather than leaving you to work out the next step alone.',
                      ),
                      (
                        'Can I use AI CV matching now?',
                        'AI CV extraction, ranked match scores, skill-gap explanations and re-matching are planned. You can start with an account, explore job listings and access the learning catalog today.',
                      ),
                      (
                        'Is JosJob free?',
                        'Job access is free for graduates. Learning opportunities may have separate course or class fees; check the price before enrolling.',
                      ),
                      (
                        'Does JosJob guarantee a job?',
                        'No. JosJob helps you explore opportunities and develop skills. Hiring decisions remain with employers, and completing a course does not guarantee employment.',
                      ),
                    ].indexed)
                      _FaqItem('Q${entry.$1 + 1}', entry.$2),
                  ],
                ),
                color: AppColors.tintBlue,
              ),
              _section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'TAKE THE FIRST STEP',
                      'Your next chapter needs a starting point.',
                      'Create your JosJob account. Explore opportunities, build your skills and take a more intentional step toward your dream job.',
                    ),
                    const SizedBox(height: 28),
                    _PillButton(
                      'Create your account',
                      onPressed: _register,
                      trailing: Icons.arrow_forward,
                    ),
                  ],
                ),
              ),
              _section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JosJob',
                      style: GoogleFonts.poppins(
                        color: AppColors.navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Job discovery and online learning for your next career move in Indonesia.',
                      style: _lead(context),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '? 2026 JosJob. Built on the Stellar learning platform.',
                      style: _lead(context).copyWith(fontSize: 13),
                    ),
                  ],
                ),
                color: AppColors.tintBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
