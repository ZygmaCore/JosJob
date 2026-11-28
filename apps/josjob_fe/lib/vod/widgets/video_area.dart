part of '../vod_page.dart';

// =========================================================================
// The video column: the dark 16:9 stage + player controls (play/pause, time,
// checkpoint seek bar).
//
// Desktop (compact == false): scrolls, with the video title/description
// below. Mobile (compact == true): a fixed header — the stage is capped to
// [maxStageHeight] (letterboxed if needed) so the panel below always has room,
// and the title lives in the top bar instead.
// =========================================================================
class _VideoArea extends StatelessWidget {
  final VodPlayback? player;
  final VodVideo video;
  final bool playing;
  final bool buffering;
  final bool videoError;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final bool compact;
  final double? maxStageHeight;

  const _VideoArea({
    required this.player,
    required this.video,
    required this.playing,
    required this.buffering,
    required this.videoError,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
    this.compact = false,
    this.maxStageHeight,
  });

  @override
  Widget build(BuildContext context) {
    final stage = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _VideoStage(
        player: player,
        playing: playing,
        buffering: buffering,
        videoError: videoError,
        onToggle: onToggle,
      ),
    );

    final controls = _PlayerControls(
      playing: playing,
      position: position,
      duration: duration,
      checkpoints: video.checkpoints,
      enabled: player?.isInitialized == true && !videoError,
      onToggle: onToggle,
      onSeek: onSeek,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (maxStageHeight != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxStageHeight!),
                child: Center(child: stage),
              )
            else
              stage,
            const SizedBox(height: 12),
            controls,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stage,
            const SizedBox(height: 14),
            controls,
            const SizedBox(height: 20),
            Text(
              video.title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            if (video.description != null) ...[
              const SizedBox(height: 8),
              Text(
                video.description!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.body,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
