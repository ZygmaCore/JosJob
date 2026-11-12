import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../vod/player/vod_playback.dart';

// =========================================================================
// JosJob — in-app player for a video Document
//
// A video document's `url` is an HLS manifest (…/manifest/video.m3u8).
// Browsers other than Safari can't play a raw .m3u8 opened in a tab, so a
// video document opens HERE — the same hls.js-backed [VodPlayback] the lecture
// player uses (createVodPlayback) — instead of a new browser tab.
//
// Standalone library (needs its own vod_playback import; a `part` can't import).
// =========================================================================
class DocumentVideoPage extends StatefulWidget {
  final String title;
  final String url;
  const DocumentVideoPage({super.key, required this.title, required this.url});

  @override
  State<DocumentVideoPage> createState() => _DocumentVideoPageState();
}

class _DocumentVideoPageState extends State<DocumentVideoPage> {
  late final VodPlayback _player = createVodPlayback(widget.url);
  bool _initialized = false;
  bool _error = false;
  // While the user drags the seek bar, show the dragged position (ms) instead
  // of the live playhead so the thumb doesn't fight the ticking position.
  double? _dragMs;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onTick);
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = _player.isInitialized;
        _error = _player.hasError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      if (_player.hasError) _error = true;
      if (_player.isInitialized) _initialized = true;
    });
  }

  void _toggle() {
    if (!_player.isInitialized) return;
    _player.isPlaying ? _player.pause() : _player.play();
  }

  @override
  void dispose() {
    _player.removeListener(_onTick);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title.isEmpty ? 'Video' : widget.title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: Center(child: _content()),
    );
  }

  Widget _content() {
    if (_error) {
      return const _PlayerMessage(
        icon: Icons.error_outline_rounded,
        text:
            "This video couldn't be played. It may still be processing, or the "
            'video service is unavailable right now.',
      );
    }
    if (!_initialized) {
      return const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
      );
    }
    final ratio = _player.aspectRatio <= 0 ? 16 / 9 : _player.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _player.buildView(),
          // Tap anywhere on the video to toggle play/pause (below the controls).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
            ),
          ),
          if (_player.isBuffering)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else if (!_player.isPlaying)
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x55000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          Positioned(left: 0, right: 0, bottom: 0, child: _controlBar()),
        ],
      ),
    );
  }

  Widget _controlBar() {
    final pos = _player.position;
    final dur = _player.duration;
    final seekable = dur.inMilliseconds > 0;
    final maxMs = seekable ? dur.inMilliseconds.toDouble() : 1.0;
    final value = (_dragMs ?? pos.inMilliseconds.toDouble()).clamp(0.0, maxMs);
    final timeStyle = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 28, 12, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            tooltip: _player.isPlaying ? 'Pause' : 'Play',
            icon: Icon(
              _player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          Text(_fmtTime(pos), style: timeStyle),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: AppColors.brandBlue,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: const Color(0x33FFFFFF),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: 0,
                max: maxMs,
                value: value,
                onChanged: seekable ? (v) => setState(() => _dragMs = v) : null,
                onChangeEnd: seekable
                    ? (v) {
                        _player.seekTo(Duration(milliseconds: v.round()));
                        setState(() => _dragMs = null);
                      }
                    : null,
              ),
            ),
          ),
          Text(_fmtTime(dur), style: timeStyle),
        ],
      ),
    );
  }

  // mm:ss (or h:mm:ss past an hour).
  String _fmtTime(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }
}

class _PlayerMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PlayerMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Colors.white70),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
