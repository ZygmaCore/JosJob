part of '../quiz_page.dart';

/// The post-submission summary: an animated score gauge, a contextual pass /
/// fail / placement banner, headline stats, a full answer review, and the
/// contextual next actions.
class _ResultsView extends StatelessWidget {
  final _Assessment assessment;
  final List<_Graded> grades;
  final double scoreFraction;
  final bool passed;
  final String elapsedLabel;
  final VoidCallback onRetake;
  final VoidCallback onDone;
  const _ResultsView({
    required this.assessment,
    required this.grades,
    required this.scoreFraction,
    required this.passed,
    required this.elapsedLabel,
    required this.onRetake,
    required this.onDone,
  });

  int get _correct => grades.where((g) => g.correct).length;
  bool get _isPlacement => assessment.tier == QuizTier.placement;

  String get _tierNoun => switch (assessment.tier) {
    QuizTier.lecture => 'lecture',
    QuizTier.section => 'section',
    _ => 'lesson',
  };

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              Center(
                child: _ScoreRing(
                  percent: scoreFraction,
                  passed: passed || _isPlacement,
                ),
              ),
              const SizedBox(height: 24),
              _banner(context),
              const SizedBox(height: 20),
              _statRow(),
              const SizedBox(height: 30),
              Text(
                'Review your answers',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < grades.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ReviewTile(index: i + 1, graded: grades[i]),
              ],
              const SizedBox(height: 28),
              _actions(context, mobile),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: onDone,
                  child: Text(
                    'Back to quizzes',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    final (
      Color bg,
      Color fg,
      IconData icon,
      String title,
      String body,
    ) = _isPlacement
        ? (
            AppColors.tintBlue,
            AppColors.brandBlue,
            Icons.route_outlined,
            'Placement complete',
            'Your personalised learning path is ready, tuned to your strengths and gaps.',
          )
        : passed
        ? (
            AppColors.tintGreen,
            AppColors.iconGreen,
            Icons.celebration_outlined,
            'You passed!',
            'Great work — the next $_tierNoun is unlocked.',
          )
        : (
            AppColors.tintOrange,
            AppColors.iconOrange,
            Icons.refresh,
            'Almost there',
            'You need ${((assessment.passMark ?? 0) * 100).round()}% to pass. Review the answers below and try again.',
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow() {
    Widget item(IconData icon, String value, String label) => Column(
      children: [
        Icon(icon, size: 20, color: AppColors.brandBlue),
        const SizedBox(height: 6),
        Text(
          value,
          style: _tabular(
            GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.body),
        ),
      ],
    );
    final mark = assessment.passMark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          item(Icons.task_alt, '$_correct / ${grades.length}', 'Correct'),
          item(Icons.schedule, elapsedLabel, 'Time'),
          item(
            Icons.flag_outlined,
            mark == null ? '—' : '${(mark * 100).round()}%',
            'Pass mark',
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, bool mobile) {
    final primary = _isPlacement
        ? _PillButton(
            'View my learning path',
            trailing: Icons.arrow_forward,
            expand: mobile,
            onPressed: () => _soon(context, 'Your learning path — coming soon'),
          )
        : passed
        ? _PillButton(
            'Continue',
            trailing: Icons.arrow_forward,
            expand: mobile,
            onPressed: () =>
                _soon(context, 'Next $_tierNoun unlocked — coming soon'),
          )
        : _PillButton(
            'Try again',
            leading: Icons.refresh,
            expand: mobile,
            onPressed: onRetake,
          );

    final retake = _PillButton(
      'Retake',
      kind: _BtnKind.ghost,
      leading: Icons.refresh,
      expand: mobile,
      onPressed: onRetake,
    );

    if (mobile) {
      return Column(
        children: [
          primary,
          const SizedBox(height: 12),
          if (passed || _isPlacement) retake,
        ],
      );
    }
    return Row(
      children: [
        if (passed || _isPlacement) ...[retake, const SizedBox(width: 12)],
        const Spacer(),
        primary,
      ],
    );
  }
}

/// One reviewed question: correctness pill, prompt, the learner's answer, the
/// correct answer (when wrong), and the explanation.
class _ReviewTile extends StatelessWidget {
  final int index;
  final _Graded graded;
  const _ReviewTile({required this.index, required this.graded});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    final correct = graded.correct;
    final (Color color, IconData icon, String label) = !graded.answered
        ? (AppColors.body, Icons.remove_circle_outline, 'Not answered')
        : correct
        ? (AppColors.iconGreen, Icons.check_circle, 'Correct')
        : (red, Icons.cancel, 'Incorrect');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  graded.question.prompt,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TagPill(label, fg: Colors.white, bg: color, icon: icon),
            ],
          ),
          const SizedBox(height: 12),
          _answerLine(
            'Your answer',
            graded.yourAnswer,
            correct ? AppColors.iconGreen : color,
          ),
          if (!correct) ...[
            const SizedBox(height: 8),
            _answerLine(
              'Correct answer',
              graded.correctAnswer,
              AppColors.iconGreen,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tintBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 17,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    graded.question.explanation,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.navy,
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

  Widget _answerLine(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.body,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
