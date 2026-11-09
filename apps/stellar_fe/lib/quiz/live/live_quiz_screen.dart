part of '../quiz_page.dart';

// =========================================================================
// Live classroom quiz — the client side of the quiz state machine:
//
//   lobby -> question -> reveal -> leaderboard -> (next segment) -> ...
//            (a poll -> pollResult can sit between questions) -> finished
//
// Pacing timers drive it automatically so the demo plays on its own; an
// optional instructor / co-host "presenter" bar lets you push each transition
// by hand (mirroring who controls the real channel). Points reward speed:
// base 100 + a time bonus. Opponent scores are scripted for a believable
// climbing leaderboard. No channels, no sockets — all local.
// =========================================================================

enum _LiveStage {
  lobby,
  question,
  reveal,
  leaderboard,
  poll,
  pollResult,
  finished,
}

class _LiveQuizScreen extends StatefulWidget {
  const _LiveQuizScreen();

  @override
  State<_LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends State<_LiveQuizScreen> {
  static const _lobby = Duration(seconds: 4);
  static const _revealHold = Duration(seconds: 5);
  static const _leaderboardHold = Duration(seconds: 5);
  static const _pollResultHold = Duration(seconds: 5);
  static const _lockHold = Duration(seconds: 2); // after you answer
  static const _pollSeconds = 15;

  _LiveStage _stage = _LiveStage.lobby;
  int _seg = 0; // index into _liveSession
  int _revealedQuestions = 0; // scored questions fully revealed so far

  int _remaining = 0;
  int _answerRemaining = 0; // seconds left when you locked your answer
  String? _selectedKey;
  int? _selectedPoll;

  int _youScore = 0;
  int _lastEarned = 0;
  bool _presenter = false;

  Timer? _countdown;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _enterLobby();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _advance?.cancel();
    super.dispose();
  }

  void _clearTimers() {
    _countdown?.cancel();
    _advance?.cancel();
  }

  _Segment get _segment => _liveSession[_seg];

  int get _totalPlayers => _liveNpcs.length + 1;

  // ---- Transitions --------------------------------------------------------
  void _enterLobby() {
    _clearTimers();
    setState(() => _stage = _LiveStage.lobby);
    _advance = Timer(_lobby, _beginSegment);
  }

  void _beginSegment() {
    if (!mounted) return;
    final seg = _segment;
    if (seg is _QuestionSeg) {
      _startQuestion(seg.question);
    } else if (seg is _PollSeg) {
      _startPoll(seg.poll);
    }
  }

  void _startQuestion(_LiveQuestion q) {
    _clearTimers();
    setState(() {
      _stage = _LiveStage.question;
      _selectedKey = null;
      _remaining = q.seconds;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _endQuestion();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _selectOption(String key) {
    if (_stage != _LiveStage.question || _selectedKey != null) return;
    setState(() {
      _selectedKey = key;
      _answerRemaining = _remaining;
    });
    _advance = Timer(_lockHold, _endQuestion); // "everyone answered"
  }

  void _endQuestion() {
    if (_stage != _LiveStage.question) return;
    _clearTimers();
    final q = (_segment as _QuestionSeg).question;
    final correct = _selectedKey == q.correctKey;
    final earned = correct
        ? 100 + ((_answerRemaining / q.seconds) * 100).round()
        : 0;
    setState(() {
      _lastEarned = earned;
      _youScore += earned;
      _revealedQuestions++;
      _stage = _LiveStage.reveal;
    });
    _advance = Timer(_revealHold, _showLeaderboard);
  }

  void _showLeaderboard() {
    if (!mounted) return;
    _clearTimers();
    setState(() => _stage = _LiveStage.leaderboard);
    _advance = Timer(_leaderboardHold, _afterLeaderboard);
  }

  void _afterLeaderboard() {
    if (!mounted) return;
    _advanceSegment();
  }

  void _startPoll(_Poll p) {
    _clearTimers();
    setState(() {
      _stage = _LiveStage.poll;
      _selectedPoll = null;
      _remaining = _pollSeconds;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _endPoll();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _votePoll(int i) {
    if (_stage != _LiveStage.poll || _selectedPoll != null) return;
    setState(() => _selectedPoll = i);
    _advance = Timer(const Duration(milliseconds: 1200), _endPoll);
  }

  void _endPoll() {
    if (_stage != _LiveStage.poll) return;
    _clearTimers();
    setState(() => _stage = _LiveStage.pollResult);
    _advance = Timer(_pollResultHold, _advanceSegment);
  }

  void _advanceSegment() {
    _clearTimers();
    if (_seg >= _liveSession.length - 1) {
      setState(() => _stage = _LiveStage.finished);
      return;
    }
    setState(() => _seg++);
    _beginSegment();
  }

  void _restart() {
    _clearTimers();
    setState(() {
      _seg = 0;
      _revealedQuestions = 0;
      _youScore = 0;
      _lastEarned = 0;
      _selectedKey = null;
      _selectedPoll = null;
    });
    _enterLobby();
  }

  // ---- Derived ------------------------------------------------------------
  int get _questionOrdinal {
    var n = 0;
    for (var i = 0; i <= _seg && i < _liveSession.length; i++) {
      if (_liveSession[i] is _QuestionSeg) n++;
    }
    return n;
  }

  List<_Player> _board() {
    final players = <_Player>[
      for (final n in _liveNpcs)
        _Player(n.name, n.scoreAfter(_revealedQuestions)),
      _Player('You', _youScore, isYou: true),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return players;
  }

  int get _yourRank {
    final b = _board();
    return b.indexWhere((p) => p.isYou) + 1;
  }

  // ---- Presenter (instructor / co-host) control for the current stage -----
  (String, IconData, VoidCallback)? get _hostAction => switch (_stage) {
    _LiveStage.lobby => (
      'Push first question',
      Icons.play_arrow,
      _beginSegment,
    ),
    _LiveStage.question => (
      'End question',
      Icons.timer_off_outlined,
      _endQuestion,
    ),
    _LiveStage.reveal => (
      'Show leaderboard',
      Icons.leaderboard_outlined,
      _showLeaderboard,
    ),
    _LiveStage.leaderboard => ('Next', Icons.skip_next, _afterLeaderboard),
    _LiveStage.poll => ('End poll', Icons.how_to_vote_outlined, _endPoll),
    _LiveStage.pollResult => ('Next', Icons.skip_next, _advanceSegment),
    _LiveStage.finished => null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _stageBody()),
            if (_presenter && _hostAction != null)
              _HostControls(
                label: _hostAction!.$1,
                icon: _hostAction!.$2,
                onPressed: _hostAction!.$3,
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
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
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Leave',
                icon: const Icon(Icons.close, color: AppColors.ink),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _liveTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_stage != _LiveStage.lobby &&
                  _stage != _LiveStage.finished) ...[
                _PointsBadge(_youScore),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: () => setState(() => _presenter = !_presenter),
                tooltip: _presenter
                    ? 'Hide presenter controls'
                    : 'Presenter controls',
                isSelected: _presenter,
                icon: Icon(
                  _presenter ? Icons.co_present : Icons.co_present_outlined,
                  color: _presenter ? AppColors.brandBlue : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageBody() {
    switch (_stage) {
      case _LiveStage.lobby:
        return const _LiveLobby(
          title: _liveTitle,
          joined: _liveJoined,
          totalQuestions: _liveQuestionCount,
        );
      case _LiveStage.question:
      case _LiveStage.reveal:
        final q = (_segment as _QuestionSeg).question;
        final revealed = _stage == _LiveStage.reveal;
        return _LiveQuestionView(
          question: q,
          number: _questionOrdinal,
          total: _liveQuestionCount,
          remaining: _remaining,
          revealed: revealed,
          selectedKey: _selectedKey,
          earned: _lastEarned,
          rank: _yourRank,
          totalPlayers: _totalPlayers,
          onSelect: _selectOption,
        );
      case _LiveStage.poll:
      case _LiveStage.pollResult:
        final p = (_segment as _PollSeg).poll;
        return _LivePollView(
          poll: p,
          remaining: _remaining,
          showResult: _stage == _LiveStage.pollResult,
          selected: _selectedPoll,
          onVote: _votePoll,
        );
      case _LiveStage.leaderboard:
        return _LiveLeaderboard(
          players: _board(),
          yourRank: _yourRank,
          finished: false,
        );
      case _LiveStage.finished:
        return _LiveLeaderboard(
          players: _board(),
          yourRank: _yourRank,
          finished: true,
          onPlayAgain: _restart,
          onExit: () => Navigator.of(context).maybePop(),
        );
    }
  }
}
