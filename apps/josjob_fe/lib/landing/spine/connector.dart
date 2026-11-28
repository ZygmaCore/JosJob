part of '../landing_page_ascent.dart';

class _Connector extends StatelessWidget {
  final int index;
  final ValueNotifier<double> fraction;
  final double height;
  final bool toSummit;
  const _Connector({
    required this.index,
    required this.fraction,
    required this.height,
    this.toSummit = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ValueListenableBuilder<double>(
        valueListenable: fraction,
        builder: (context, f, _) {
          final fill = (f * _milestoneCount - index).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _SpineSegmentPainter(fill: fill, headDot: !toSummit),
          );
        },
      ),
    );
  }
}

class _SpineSegmentPainter extends CustomPainter {
  final double fill; // 0..1 solid gradient fill from the top
  final bool showTrack; // dotted "upcoming" track behind the fill
  final bool fadeTop; // soft fade-in at the very top (start cap)
  final bool headDot; // glowing dot at the fill head while in progress
  const _SpineSegmentPainter({
    required this.fill,
    this.showTrack = true,
    this.fadeTop = false,
    this.headDot = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const sw = 3.0;
    if (showTrack) {
      final dot = Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.fill;
      var y = 2.0;
      while (y <= size.height) {
        canvas.drawCircle(Offset(x, y), 1.7, dot);
        y += 9;
      }
    }
    final fillH = (size.height * fill).clamp(0.0, size.height);
    if (fillH > 0) {
      final rect = Rect.fromLTWH(x - sw / 2, 0, sw, size.height);
      final colors = fadeTop
          ? [
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent,
              AppColors.brandBlue,
            ]
          : const [AppColors.accent, AppColors.heroBlue, AppColors.brandBlue];
      final line = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: fadeTop ? const [0.0, 0.45, 1.0] : null,
        ).createShader(rect)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, 0), Offset(x, fillH), line);
      if (headDot && fill > 0.03 && fill < 0.97) {
        canvas.drawCircle(
          Offset(x, fillH),
          8,
          Paint()..color = AppColors.brandBlue.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          Offset(x, fillH),
          4.5,
          Paint()..color = AppColors.brandBlue,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpineSegmentPainter old) =>
      old.fill != fill ||
      old.showTrack != showTrack ||
      old.fadeTop != fadeTop ||
      old.headDot != headDot;
}
