import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart' show AppColors;
import 'data/live_models.dart';
import 'service/live_session_controller.dart';

// =========================================================================
// JosJob — Live call (WebRTC via Cloudflare Realtime SFU)
//
// Public entry widget for a live video session — classroom, 1-on-1, or
// coaching. Owns a [LiveSessionController] (created in initState, disposed in
// dispose) and rebuilds on its notifications. Pushed via MaterialPageRoute from
// the dashboard (Live Coaching), so it inherits the app's auth guard.
//
// Assembled from `part` files (one component per file). The controller +
// signaling + models are TOP-LEVEL imports (they carry the flutter_webrtc /
// phoenix_socket deps), mirroring lib/vod/player/vod_playback.dart.
// =========================================================================

part 'shell/live_scaffold.dart';
part 'widgets/participant_layout.dart';
part 'widgets/video_tile.dart';
part 'widgets/control_bar.dart';
part 'widgets/live_status_views.dart';

class LiveCallPage extends StatefulWidget {
  const LiveCallPage({
    super.key,
    required this.roomId,
    required this.mode,
    required this.role,
    this.displayName,
  });

  final String roomId;
  final LiveRoomMode mode;
  final ParticipantRole role;
  final String? displayName;

  @override
  State<LiveCallPage> createState() => _LiveCallPageState();
}

class _LiveCallPageState extends State<LiveCallPage> {
  late final LiveSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LiveSessionController(
      roomId: widget.roomId,
      mode: widget.mode,
      role: widget.role,
      displayName: widget.displayName ?? 'Peserta',
    );
    _controller.addListener(_onChange);
    _controller.connect();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LiveScaffold(
      controller: _controller,
      onLeave: () => Navigator.of(context).maybePop(),
    );
  }
}

// ---- library-private shared tokens (dark call chrome) -------------------

const Color _callBg = Color(0xFF0B1622);
const Color _tileBg = Color(0xFF14273D);
const Color _danger = Color(0xFFE5484D);

TextStyle _poppins(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

/// Initials from a display name, e.g. "Ana Rivera" -> "AR".
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
