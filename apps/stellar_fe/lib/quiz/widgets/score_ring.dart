part of '../quiz_page.dart';

/// Large animated results gauge. The arc sweeps from 0 to [percent] on mount
/// (instant under reduced motion) and the centre shows the whole-number score.
/// Green when [passed], amber otherwise.
class _ScoreRing extends StatelessWidget {
  final double percent; // 0..1
  final bool passed;
  const _ScoreRing({required this.percent, required this.passed});

  @override
  Widget build(BuildContext context) {
    const size = 168.0;
    final color = passed ? AppColors.iconGreen : AppColors.orange;
    final pct = (percent * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: 'Score $pct percent',
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percent.clamp(0.0, 1.0)),
          duration: _reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _ScoreRingPainter(fraction: value, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}%',
                    style: _tabular(
                      GoogleFonts.poppins(
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    passed ? 'Passed' : 'Not yet',
                    style: GoogleFonts.poppins(
                      fontSize: size * 0.09,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _ScoreRingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.085;
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.border;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.6), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.fraction != fraction || old.color != color;
}
