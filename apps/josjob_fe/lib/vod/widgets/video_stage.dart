part of '../vod_page.dart';

// =========================================================================
// The dark 16:9 video surface. Click-to-play (no autoplay); shows a large
// play affordance while paused, a buffering spinner, and a graceful error
// overlay (e.g. Chrome/Firefox lack native HLS — the surrounding controls,
// topics and transcript still work).
// =========================================================================
class _VideoStage extends StatelessWidget {
  final VodPlayback? player;
  final bool playing;
  final bool buffering;
  final bool videoError;
  final VoidCallback onToggle;

  const _VideoStage({
    required this.player,
    required this.playing,
    required this.buffering,
    required this.videoError,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    final ready = p != null && p.isInitialized;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: _stageBg,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: p.aspectRatio,
                  child: p.buildView(),
                ),
              ),

            // Tap anywhere to toggle play/pause (only once playable).
            if (ready && !videoError)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: playing ? 'Pause' : 'Play',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: AnimatedOpacity(
                      duration: _anim(context, 200),
                      opacity: playing ? 0 : 1,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.28),
                        alignment: Alignment.center,
                        child: const _PlayGlyph(),
                      ),
                    ),
                  ),
                ),
              ),

            if (buffering && !videoError)
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),

            if (videoError) const _StageError(),
            if (!ready && !videoError)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// The circular play button shown over a paused video.
class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.brandBlue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}

// Shown when the stream genuinely can't be loaded (network/CORS/decoding).
class _StageError extends StatelessWidget {
  const _StageError();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.smart_display_outlined,
            color: Colors.white70,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            "This video couldn't be loaded",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The stream may still be processing or is temporarily unavailable. '
            'The topics and transcript below still work.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
