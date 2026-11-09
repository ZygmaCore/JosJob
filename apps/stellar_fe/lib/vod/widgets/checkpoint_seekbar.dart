part of '../vod_page.dart';

// =========================================================================
// A scrub bar with topic CHECKPOINT MARKERS. Tap or drag to seek; a tap
// within ~10px of a marker snaps to that checkpoint. The visual track is
// thin but the gesture surface is 44px tall (touch-target friendly).
// =========================================================================
class _CheckpointSeekbar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final List<VideoCheckpoint> checkpoints;
  final bool enabled;
  final ValueChanged<Duration> onSeek;

  const _CheckpointSeekbar({
    required this.position,
    required this.duration,
    required this.checkpoints,
    required this.enabled,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void seekToDx(double dx) {
          if (!enabled || totalMs <= 0 || width <= 0) return;
          var frac = (dx / width).clamp(0.0, 1.0);
          // Snap to a nearby checkpoint marker.
          for (final cp in checkpoints) {
            final cpFrac = (cp.startSeconds * 1000) / totalMs;
            if ((cpFrac * width - dx).abs() <= 10) {
              frac = cpFrac.clamp(0.0, 1.0);
              break;
            }
          }
          onSeek(Duration(milliseconds: (frac * totalMs).round()));
        }

        final fraction = totalMs > 0
            ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;
        final markers = totalMs > 0
            ? [
                for (final cp in checkpoints)
                  ((cp.startSeconds * 1000) / totalMs).clamp(0.0, 1.0),
              ]
            : const <double>[];

        return Semantics(
          slider: true,
          label: 'Seek bar',
          value: '${_fmtTime(position)} of ${_fmtTime(duration)}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekToDx(d.localPosition.dx),
            onHorizontalDragStart: (d) => seekToDx(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => seekToDx(d.localPosition.dx),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(
                painter: _SeekbarPainter(
                  fraction: fraction.toDouble(),
                  markers: markers.map((m) => m.toDouble()).toList(),
                  enabled: enabled,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekbarPainter extends CustomPainter {
  final double fraction;
  final List<double> markers;
  final bool enabled;

  _SeekbarPainter({
    required this.fraction,
    required this.markers,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 6.0;
    final radius = const Radius.circular(3);

    // Track (background).
    final trackRect = RRect.fromLTRBR(
      0,
      cy - trackH / 2,
      size.width,
      cy + trackH / 2,
      radius,
    );
    canvas.drawRRect(trackRect, Paint()..color = AppColors.border);

    // Played portion.
    final playedW = (size.width * fraction).clamp(0.0, size.width);
    if (playedW > 0) {
      final playedRect = RRect.fromLTRBR(
        0,
        cy - trackH / 2,
        playedW,
        cy + trackH / 2,
        radius,
      );
      canvas.drawRRect(
        playedRect,
        Paint()..color = enabled ? AppColors.brandBlue : AppColors.body,
      );
    }

    // Checkpoint markers.
    final markerPaint = Paint()..color = AppColors.orange;
    for (final m in markers) {
      final x = (size.width * m).clamp(0.0, size.width);
      final markRect = RRect.fromLTRBR(
        x - 1.5,
        cy - 7,
        x + 1.5,
        cy + 7,
        const Radius.circular(1.5),
      );
      canvas.drawRRect(markRect, markerPaint);
    }

    // Thumb.
    if (enabled) {
      final tx = (size.width * fraction).clamp(0.0, size.width);
      canvas.drawCircle(Offset(tx, cy), 8, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(tx, cy),
        8,
        Paint()
          ..color = AppColors.brandBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekbarPainter old) =>
      old.fraction != fraction ||
      old.enabled != enabled ||
      old.markers.length != markers.length;
}
