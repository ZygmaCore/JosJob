part of '../quiz_page.dart';

/// The pre-quiz briefing: what this assessment is, how long it takes, the pass
/// rule, and how it behaves. One primary "Start" action.
class _AssessmentIntro extends StatelessWidget {
  final _Assessment assessment;
  final VoidCallback onStart;
  const _AssessmentIntro({required this.assessment, required this.onStart});

  String get _kindsLine {
    final kinds = <String>{
      for (final q in assessment.questions)
        switch (q) {
          _McqQuestion() => 'multiple-choice',
          _OpenQuestion() => 'open response',
          _MatchQuestion() => 'matching',
        },
    };
    return kinds.join(' · ');
  }

  String get _rule {
    final mark = assessment.passMark;
    if (mark == null) {
      return assessment.tier == QuizTier.placement
          ? 'Adaptive — no pass or fail'
          : 'Extra credit';
    }
    return 'Pass ${(mark * 100).round()}%';
  }

  List<String> get _instructions {
    final base = [
      'Answer each question, then continue — you can step back at any time.',
      'You will see your score and a full answer review at the end.',
    ];
    switch (assessment.tier) {
      case QuizTier.placement:
        base.add(
          'This check maps your strengths and gaps to build your learning path. '
          'There is no pass or fail.',
        );
      case QuizTier.lecture:
        base.add('Score at least 70% to unlock the next lecture.');
      case QuizTier.section:
        base.add('Score at least 75% to unlock the next section.');
      case QuizTier.live:
        break;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final mobile = _isMobile(context);
    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: a.tier.tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(a.tier.icon, color: a.tier.accent, size: 34),
              ),
              const SizedBox(height: 18),
              _TagPill(
                a.tier.label,
                fg: a.tier.accent,
                bg: a.tier.tint,
                icon: a.tier == QuizTier.live ? Icons.sensors : Icons.schedule,
              ),
              const SizedBox(height: 14),
              Text(a.title, style: _h2s(context)),
              const SizedBox(height: 8),
              Text(a.subtitle, style: _lead(context)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: 22,
                  runSpacing: 12,
                  children: [
                    _StatChip(
                      Icons.help_outline,
                      '${a.questions.length} questions',
                      color: AppColors.navy,
                    ),
                    _StatChip(
                      Icons.schedule,
                      '~${a.estMinutes} min',
                      color: AppColors.navy,
                    ),
                    _StatChip(
                      Icons.flag_outlined,
                      _rule,
                      color: AppColors.navy,
                    ),
                    _StatChip(
                      Icons.category_outlined,
                      _kindsLine,
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              for (final line in _instructions) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: a.tier.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: mobile ? double.infinity : null,
                child: _PillButton(
                  'Start assessment',
                  leading: Icons.play_arrow_rounded,
                  expand: mobile,
                  onPressed: onStart,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
