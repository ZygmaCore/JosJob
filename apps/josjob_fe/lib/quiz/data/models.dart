part of '../quiz_page.dart';

// =========================================================================
// Domain models for the assessment tiers and the live classroom quiz.
// Hand-authored fixtures — immutable, plain, no persistence.
// =========================================================================

/// The four assessment tiers from the platform's multi-tier model.
enum QuizTier { placement, lecture, section, live }

extension QuizTierX on QuizTier {
  String get label => switch (this) {
    QuizTier.placement => 'Placement assessment',
    QuizTier.lecture => 'Lecture-level quiz',
    QuizTier.section => 'Section assessment',
    QuizTier.live => 'Live classroom quiz',
  };

  String get timing => switch (this) {
    QuizTier.placement => 'During registration',
    QuizTier.lecture => 'After every lecture',
    QuizTier.section => 'After every section',
    QuizTier.live => 'During a live class',
  };

  IconData get icon => switch (this) {
    QuizTier.placement => Icons.explore_outlined,
    QuizTier.lecture => Icons.play_lesson_outlined,
    QuizTier.section => Icons.workspace_premium_outlined,
    QuizTier.live => Icons.bolt_outlined,
  };

  /// Pass threshold as a fraction, or null for the live quiz (extra credit).
  double? get passMark => switch (this) {
    QuizTier.placement => null, // adaptive: maps skills, no pass/fail
    QuizTier.lecture => 0.70,
    QuizTier.section => 0.75,
    QuizTier.live => null,
  };

  Color get accent => switch (this) {
    QuizTier.placement => AppColors.iconBlue,
    QuizTier.lecture => AppColors.brandBlue,
    QuizTier.section => AppColors.iconGreen,
    QuizTier.live => AppColors.orange,
  };

  Color get tint => switch (this) {
    QuizTier.placement => AppColors.tintBlue,
    QuizTier.lecture => AppColors.tintBlue,
    QuizTier.section => AppColors.tintGreen,
    QuizTier.live => AppColors.tintOrange,
  };
}

// ---- Self-paced assessment ----------------------------------------------

/// A single answer option (key "A".."D" + display text).
class _Option {
  final String key;
  final String text;
  const _Option(this.key, this.text);
}

/// A left/right pair for a matching question. Correct mapping is index-aligned
/// (left[i] pairs with right[i]); the right column is shown shuffled.
class _MatchPair {
  final String left;
  final String right;
  const _MatchPair(this.left, this.right);
}

/// Sealed so the question renderer + scorer switch exhaustively over kinds.
sealed class _Question {
  final String id;
  final String prompt;
  final String explanation;
  const _Question(this.id, this.prompt, this.explanation);
}

class _McqQuestion extends _Question {
  final List<_Option> options;
  final String correctKey;
  const _McqQuestion({
    required String id,
    required String prompt,
    required this.options,
    required this.correctKey,
    required String explanation,
  }) : super(id, prompt, explanation);
}

class _OpenQuestion extends _Question {
  final String modelAnswer;

  /// Any one of these (case-insensitive substring) marks the answer correct —
  /// a lightweight, offline stand-in for real grading.
  final List<String> keywords;
  const _OpenQuestion({
    required String id,
    required String prompt,
    required this.modelAnswer,
    required this.keywords,
    required String explanation,
  }) : super(id, prompt, explanation);
}

class _MatchQuestion extends _Question {
  final List<_MatchPair> pairs;
  const _MatchQuestion({
    required String id,
    required String prompt,
    required this.pairs,
    required String explanation,
  }) : super(id, prompt, explanation);
}

class _Assessment {
  final String title;
  final QuizTier tier;
  final String subtitle;
  final int estMinutes;
  final List<_Question> questions;
  const _Assessment({
    required this.title,
    required this.tier,
    required this.subtitle,
    required this.estMinutes,
    required this.questions,
  });

  double? get passMark => tier.passMark;
}

// ---- Live classroom quiz -------------------------------------------------

class _LiveQuestion {
  final String prompt;
  final List<_Option> options;
  final String correctKey;
  final String explanation;
  final int seconds; // time limit
  const _LiveQuestion({
    required this.prompt,
    required this.options,
    required this.correctKey,
    required this.explanation,
    required this.seconds,
  });
}

class _Poll {
  final String prompt;
  final List<String> options;
  final List<int> tally; // final vote counts per option (from other students)
  const _Poll({
    required this.prompt,
    required this.options,
    required this.tally,
  });

  int get total => tally.fold(0, (a, b) => a + b);
}

/// One step of a live session — either a scored question or a quick poll.
sealed class _Segment {
  const _Segment();
}

class _QuestionSeg extends _Segment {
  final _LiveQuestion question;
  const _QuestionSeg(this.question);
}

class _PollSeg extends _Segment {
  final _Poll poll;
  const _PollSeg(this.poll);
}

/// A room member on the leaderboard.
class _Player {
  final String name;
  final int score;
  final bool isYou;
  const _Player(this.name, this.score, {this.isYou = false});
}

/// A scripted opponent: [perQuestion] holds the points they gain on each
/// scored question (by question index), letting the leaderboard move
/// deterministically without a backend.
class _Npc {
  final String name;
  final List<int> perQuestion;
  const _Npc(this.name, this.perQuestion);

  /// Cumulative score once [answered] questions have been revealed.
  int scoreAfter(int answered) {
    var s = 0;
    for (var i = 0; i < answered && i < perQuestion.length; i++) {
      s += perQuestion[i];
    }
    return s;
  }
}
