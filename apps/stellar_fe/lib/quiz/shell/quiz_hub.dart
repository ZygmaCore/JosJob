part of '../quiz_page.dart';

// =========================================================================
// The quiz hub (public QuizPage delegates here). A scrollable page under a
// fixed top bar: a hero, the four tier cards, and the progression explainer.
// Tapping a self-paced tier pushes the assessment runner; the live tier pushes
// the classroom-quiz state machine.
// =========================================================================
class _QuizHub extends StatefulWidget {
  final bool autoStartLive;
  final String? openQuizId;
  const _QuizHub({this.autoStartLive = false, this.openQuizId});

  @override
  State<_QuizHub> createState() => _QuizHubState();
}

class _QuizHubState extends State<_QuizHub> {
  @override
  void initState() {
    super.initState();
    // Deep-link entries fast-forward past the hub on first frame.
    final quizId = widget.openQuizId;
    if (quizId != null) {
      final assessment = _assessmentById(quizId);
      if (assessment != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openAssessment(context, assessment);
        });
      }
    } else if (widget.autoStartLive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTier(context, QuizTier.live);
      });
    }
  }

  void _goHome(BuildContext c) {
    final nav = Navigator.of(c);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const StellarLandingPage()),
      );
    }
  }

  void _openTier(BuildContext c, QuizTier tier) {
    if (tier == QuizTier.live) {
      Navigator.of(
        c,
      ).push(MaterialPageRoute(builder: (_) => const _LiveQuizScreen()));
    } else {
      _openAssessment(c, _assessmentFor(tier));
    }
  }

  void _openAssessment(BuildContext c, _Assessment assessment) {
    Navigator.of(c).push(
      MaterialPageRoute(
        builder: (_) => _AssessmentRunner(assessment: assessment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: Bp.navHeight),
                const _Hero(),
                _Bounded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Available quizzes',
                        style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _QuizCatalog(
                        onOpen: (a) => _openAssessment(context, a),
                        onLive: () => _openTier(context, QuizTier.live),
                      ),
                      const SizedBox(height: 40),
                      const _ProgressionBand(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
                const _Footer(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _QuizTopNav(onBack: () => _goHome(context)),
          ),
        ],
      ),
    );
  }
}

/// Hub hero: title, lead and a row of at-a-glance facts.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return _Bounded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _isMobile(context) ? 26 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TagPill(
              'Assessments & quizzes',
              fg: AppColors.brandBlue,
              bg: AppColors.tintBlue,
              icon: Icons.quiz_outlined,
            ),
            const SizedBox(height: 16),
            Text(
              "Test what you know. Unlock what's next.",
              style: _h2s(context),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                'Placement, lecture and section checks keep your personalised '
                'learning path on track — and live classroom quizzes turn '
                'review into a game.',
                style: _lead(context),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _StatChip(
                  Icons.layers_outlined,
                  '${_quizCatalog.values.fold<int>(0, (n, l) => n + l.length)} self-paced quizzes',
                ),
                const _StatChip(Icons.bolt_outlined, '1 live classroom game'),
                const _StatChip(
                  Icons.checklist_outlined,
                  'Multiple-choice · open · matching',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The quiz catalog: the concrete quizzes grouped by tier, each opening its
/// runner. The live quiz is its own entry (opens the live classroom screen).
class _QuizCatalog extends StatelessWidget {
  final void Function(_Assessment) onOpen;
  final VoidCallback onLive;
  const _QuizCatalog({required this.onOpen, required this.onLive});

  static String _meta(_Assessment a) {
    final mark = a.passMark;
    final rule = mark != null
        ? 'Pass ${(mark * 100).round()}%'
        : (a.tier == QuizTier.placement ? 'Adaptive' : 'Extra credit');
    return '${a.questions.length} questions · ~${a.estMinutes} min · $rule';
  }

  Widget _header(QuizTier tier) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tier.icon, size: 18, color: tier.accent),
            const SizedBox(width: 8),
            Text(
              tier.label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        _TagPill(tier.timing, fg: tier.accent, bg: tier.tint),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tier in const [
          QuizTier.placement,
          QuizTier.lecture,
          QuizTier.section,
        ]) ...[
          _header(tier),
          for (final a in _quizCatalog[tier]!) ...[
            _QuizCard(
              tier: a.tier,
              title: a.title,
              subtitle: a.subtitle,
              meta: _meta(a),
              cta: 'Start',
              onTap: () => onOpen(a),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
        ],
        _header(QuizTier.live),
        _QuizCard(
          tier: QuizTier.live,
          title: _liveTitle,
          subtitle:
              'Real-time and gamified — earn points and climb the leaderboard',
          meta: '$_liveQuestionCount questions · Live · Points & leaderboard',
          cta: 'Join',
          onTap: onLive,
        ),
      ],
    );
  }
}
