import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/vod_api.dart';
import 'player/vod_playback.dart';

// =========================================================================
// ATVETI STELLAR — Video-on-Demand video player
//
// Plays an HLS video fetched from the backend (GET /api/lectures/:id via
// lib/services/vod_api.dart) with an interactive, checkpoint-aware experience:
//   • a dark 16:9 video stage (click-to-play; buffering + error states),
//   • a scrub bar with topic CHECKPOINT MARKERS (tap/drag to seek, snaps to
//     nearby markers),
//   • a tabbed side panel — "Topics" (a table of contents that highlights the
//     active checkpoint) and "Transcript" (paragraphs that highlight and
//     auto-scroll with playback; tap to seek).
//
// Responsive: desktop (>=1024) shows the video left + panel right; narrower
// screens stack the video on top with the tabbed panel below. Reduced-motion
// safe. Reached via route '/vod' (first ready video) or pushed with a
// specific videoId from the dashboard "Resume" action.
//
// Assembled from `part` files, one component per file, grouped under
// data/ shell/ widgets/. This library file owns every import and public
// symbol; part files carry no imports of their own.
// =========================================================================

// ---- shell --------------------------------------------------------------
part 'shell/vod_shell.dart';
part 'shell/side_panel.dart';
part 'shell/vod_chrome.dart';

// ---- widgets ------------------------------------------------------------
part 'widgets/video_area.dart';
part 'widgets/video_stage.dart';
part 'widgets/player_controls.dart';
part 'widgets/checkpoint_seekbar.dart';
part 'widgets/topic_drawer.dart';
part 'widgets/transcript_panel.dart';

// =========================================================================
// Public entry point — imported by main.dart (route '/vod') and the dashboard.
// [videoId] null -> the player resolves the first ready video from the API.
// =========================================================================
class VodPlayerPage extends StatelessWidget {
  final String? videoId;
  const VodPlayerPage({super.key, this.videoId});

  @override
  Widget build(BuildContext context) => _VodShell(videoId: videoId);
}

// =========================================================================
// Shared library-private tokens & helpers (visible to every part file).
// =========================================================================

/// The dark video-stage surface. Deliberately darker than [AppColors.ink] so
/// the light page chrome and side panel read as a clear "video-first" split.
const Color _stageBg = Color(0xFF0A1420);

const double _kPanelWidth = 380;

bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

Duration _anim(BuildContext c, int ms) =>
    _reduceMotion(c) ? Duration.zero : Duration(milliseconds: ms);

/// "m:ss" (or "h:mm:ss" past an hour) for the player time labels.
String _fmtTime(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Tabular figures so time labels don't jitter as digits change.
TextStyle _tabular(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
