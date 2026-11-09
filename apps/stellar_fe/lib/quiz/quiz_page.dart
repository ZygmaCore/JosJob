import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../landing/landing_page_ascent.dart' show StellarLandingPage;

// =========================================================================
// ATVETI STELLAR — Assessments & Quizzes (UI only, no backend)
//
// A single hub (route '/quiz') that fronts two distinct experiences drawn
// from the platform's multi-tier assessment model:
//
//   1. SELF-PACED ASSESSMENT  (assessment/) — the placement / lecture /
//      section quiz taker: an intro card, a paced run of multiple-choice,
//      open-ended and matching questions with progress + a soft timer, then
//      an animated results screen with a pass/fail threshold and a full
//      answer review.
//
//   2. LIVE CLASSROOM QUIZ    (live/) — a gamified, Kahoot-style state
//      machine (lobby -> timed question -> answer reveal + points ->
//      leaderboard, with an interleaved live poll). Driven by pacing timers,
//      with an optional instructor/co-host "presenter" control bar so the
//      demo can be advanced by hand.
//
// Everything is hard-coded sample content — no channels, no persistence.
// On-brand throughout: AppColors blue palette (brandBlue primary, navy ink,
// orange as the gamified "points/gold" accent), Poppins via google_fonts,
// green = correct / red = incorrect. Responsive desktop + mobile, keyboard
// focusable, and reduced-motion safe.
//
// Assembled from `part` files, one component per file, grouped under
// data/ widgets/ shell/ assessment/ live/. This library file owns every
// import and public symbol; part files carry no imports of their own.
// =========================================================================

// ---- data ---------------------------------------------------------------
part 'data/helpers.dart';
part 'data/models.dart';
part 'data/data.dart';

// ---- widgets ------------------------------------------------------------
part 'widgets/hover_lift.dart';
part 'widgets/pill_button.dart';
part 'widgets/tag_pill.dart';
part 'widgets/stat_chip.dart';
part 'widgets/points_badge.dart';
part 'widgets/quiz_progress_bar.dart';
part 'widgets/countdown_ring.dart';
part 'widgets/score_ring.dart';
part 'widgets/option_tile.dart';
part 'widgets/live_option_tile.dart';
part 'widgets/matching_board.dart';
part 'widgets/open_answer_field.dart';
part 'widgets/leaderboard_row.dart';
part 'widgets/poll_bar.dart';
part 'widgets/quiz_card.dart';

// ---- shell --------------------------------------------------------------
part 'shell/bounded.dart';
part 'shell/quiz_logo.dart';
part 'shell/quiz_top_nav.dart';
part 'shell/progression_band.dart';
part 'shell/quiz_footer.dart';
part 'shell/quiz_hub.dart';

// ---- assessment (self-paced flow) ---------------------------------------
part 'assessment/assessment_runner.dart';
part 'assessment/assessment_intro.dart';
part 'assessment/question_view.dart';
part 'assessment/results_view.dart';

// ---- live (classroom quiz state machine) --------------------------------
part 'live/live_quiz_screen.dart';
part 'live/host_controls.dart';
part 'live/live_lobby.dart';
part 'live/live_question.dart';
part 'live/live_reveal.dart';
part 'live/live_poll.dart';
part 'live/live_leaderboard.dart';

// =========================================================================
// Public entry point — imported by main.dart (route '/quiz').
// =========================================================================
class QuizPage extends StatelessWidget {
  /// When true, the hub immediately opens the live classroom quiz — used by the
  /// dashboard's "Join" live-coaching action to jump straight into a session.
  final bool autoStartLive;

  /// When set, the hub deep-links straight to that course's quiz — used by the
  /// dashboard's per-course "Resume" action. Ignored if the id is unknown.
  final String? openQuizId;
  const QuizPage({super.key, this.autoStartLive = false, this.openQuizId});

  @override
  Widget build(BuildContext context) =>
      _QuizHub(autoStartLive: autoStartLive, openQuizId: openQuizId);
}
