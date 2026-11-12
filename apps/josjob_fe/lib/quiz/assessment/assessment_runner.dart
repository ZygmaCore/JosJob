part of '../quiz_page.dart';

// =========================================================================
// Self-paced assessment orchestrator. Owns all answer state for one
// assessment, walks intro -> questions -> results, grades locally, and hosts
// the shared top bar + navigation. Pushed from the hub as its own route.
// =========================================================================

enum _Phase { intro, quiz, results }

/// A graded question for the review screen.
class _Graded {
  final _Question question;
  final bool answered;
  final bool correct;
  final String yourAnswer;
  final String correctAnswer;
  const _Graded({
    required this.question,
    required this.answered,
    required this.correct,
    required this.yourAnswer,
    required this.correctAnswer,
  });
}

class _AssessmentRunner extends StatefulWidget {
  final _Assessment assessment;
  const _AssessmentRunner({required this.assessment});

  @override
  State<_AssessmentRunner> createState() => _AssessmentRunnerState();
}

class _AssessmentRunnerState extends State<_AssessmentRunner> {
  _Phase _phase = _Phase.intro;
  int _index = 0;

  // Answer stores, keyed by question id.
  final Map<String, String> _mcq = {}; // id -> selected key
  final Map<String, TextEditingController> _open = {};
  final Map<String, Map<int, int>> _match = {}; // id -> (leftIdx -> rightOrig)
  final Map<String, List<int>> _rightOrder = {}; // id -> shuffled right indices

  int _elapsed = 0;
  Timer? _timer;
  List<_Graded> _grades = const [];

  List<_Question> get _qs => widget.assessment.questions;
  _Question get _current => _qs[_index];

  @override
  void initState() {
    super.initState();
    for (final q in _qs) {
      if (q is _OpenQuestion) _open[q.id] = TextEditingController();
      if (q is _MatchQuestion) {
        final n = q.pairs.length;
        _rightOrder[q.id] = [for (var i = 0; i < n; i++) (i + 1) % n];
        _match[q.id] = {};
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _open.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Flow ---------------------------------------------------------------
  void _start() {
    setState(() {
      _phase = _Phase.quiz;
      _index = 0;
      _elapsed = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _next() {
    if (_index < _qs.length - 1) {
      setState(() => _index++);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  void _submit() {
    _timer?.cancel();
    setState(() {
      _grades = _qs.map(_grade).toList();
      _phase = _Phase.results;
    });
  }

  void _retake() {
    for (final c in _open.values) {
      c.clear();
    }
    setState(() {
      _mcq.clear();
      for (final e in _match.entries) {
        e.value.clear();
      }
      _grades = const [];
      _index = 0;
    });
    _start();
  }

  // ---- Grading ------------------------------------------------------------
  _Graded _grade(_Question q) {
    switch (q) {
      case _McqQuestion():
        final sel = _mcq[q.id];
        final correctText = q.options
            .firstWhere((o) => o.key == q.correctKey)
            .text;
        final yourText = sel == null
            ? '(no answer)'
            : '$sel. ${q.options.firstWhere((o) => o.key == sel).text}';
        return _Graded(
          question: q,
          answered: sel != null,
          correct: sel == q.correctKey,
          yourAnswer: yourText,
          correctAnswer: '${q.correctKey}. $correctText',
        );
      case _OpenQuestion():
        final text = (_open[q.id]?.text ?? '').trim();
        final hay = text.toLowerCase();
        final hit =
            text.isNotEmpty &&
            q.keywords.any((k) => hay.contains(k.toLowerCase()));
        return _Graded(
          question: q,
          answered: text.isNotEmpty,
          correct: hit,
          yourAnswer: text.isEmpty ? '(no answer)' : text,
          correctAnswer: q.modelAnswer,
        );
      case _MatchQuestion():
        final map = _match[q.id] ?? const {};
        final all =
            map.length == q.pairs.length &&
            map.entries.every((e) => e.key == e.value);
        final correctText = q.pairs
            .map((p) => '${p.left} → ${p.right}')
            .join('   ·   ');
        final yourText = map.isEmpty
            ? '(no answer)'
            : [
                for (var i = 0; i < q.pairs.length; i++)
                  if (map.containsKey(i))
                    '${q.pairs[i].left} → ${q.pairs[map[i]!].right}',
              ].join('   ·   ');
        return _Graded(
          question: q,
          answered: map.length == q.pairs.length,
          correct: all,
          yourAnswer: yourText,
          correctAnswer: correctText,
        );
    }
  }

  // ---- Answered-gate for the current question -----------------------------
  bool get _answered {
    final q = _current;
    switch (q) {
      case _McqQuestion():
        return _mcq.containsKey(q.id);
      case _OpenQuestion():
        return (_open[q.id]?.text.trim().isNotEmpty) ?? false;
      case _MatchQuestion():
        return (_match[q.id]?.length ?? 0) == q.pairs.length;
    }
  }

  double get _scoreFraction {
    if (_grades.isEmpty) return 0;
    final correct = _grades.where((g) => g.correct).length;
    return correct / _grades.length;
  }

  bool get _passed {
    final mark = widget.assessment.passMark;
    return mark == null ? true : _scoreFraction >= mark;
  }

  static String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _confirmExit() async {
    if (_phase != _Phase.quiz) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(
          'Leave this quiz?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your progress on this attempt will not be saved.',
          style: GoogleFonts.poppins(color: AppColors.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Stay', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              'Leave',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: switch (_phase) {
                _Phase.intro => _AssessmentIntro(
                  assessment: widget.assessment,
                  onStart: _start,
                ),
                _Phase.quiz => _quizBody(),
                _Phase.results => _ResultsView(
                  assessment: widget.assessment,
                  grades: _grades,
                  scoreFraction: _scoreFraction,
                  passed: _passed,
                  elapsedLabel: _mmss(_elapsed),
                  onRetake: _retake,
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final a = widget.assessment;
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.navy.withValues(alpha: 0.08),
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _confirmExit,
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: AppColors.ink),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      a.tier.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(a.tier.icon, color: a.tier.accent, size: 22),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quizBody() {
    final q = _current;
    final last = _index == _qs.length - 1;
    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 22),
              _QuizProgressBar(
                current: _index + 1,
                total: _qs.length,
                trailing: _StatChip(Icons.schedule, _mmss(_elapsed)),
              ),
              const SizedBox(height: 24),
              _QuestionView(
                question: q,
                selectedKey: q is _McqQuestion ? _mcq[q.id] : null,
                onSelectOption: q is _McqQuestion
                    ? (k) => setState(() => _mcq[q.id] = k)
                    : null,
                openController: q is _OpenQuestion ? _open[q.id] : null,
                onOpenChanged: () => setState(() {}),
                rightOrder: q is _MatchQuestion ? _rightOrder[q.id] : null,
                assignment: q is _MatchQuestion ? _match[q.id] : null,
                onAssign: q is _MatchQuestion
                    ? (l, r) => setState(() {
                        final m = _match[q.id]!;
                        m.removeWhere((_, v) => v == r); // keep right unique
                        m[l] = r;
                      })
                    : null,
                onClearMatch: q is _MatchQuestion
                    ? (l) => setState(() => _match[q.id]!.remove(l))
                    : null,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  if (_index > 0)
                    _PillButton(
                      'Back',
                      kind: _BtnKind.ghost,
                      leading: Icons.arrow_back,
                      onPressed: _prev,
                    ),
                  const Spacer(),
                  _PillButton(
                    last ? 'Submit' : 'Next',
                    trailing: last ? Icons.check : Icons.arrow_forward,
                    onPressed: _answered ? _next : null,
                  ),
                ],
              ),
              if (!_answered) ...[
                const SizedBox(height: 12),
                Text(
                  'Answer the question to continue.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
