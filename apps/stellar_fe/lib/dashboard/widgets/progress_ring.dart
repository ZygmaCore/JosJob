part of '../dashboard_page.dart';

// =========================================================================
// Circular progress ring with a centered % label. Custom-painted, static.
// =========================================================================
class _ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  const _ProgressRing({required this.value, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      value: '$pct percent',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ProgressRingPainter(
            value: value.clamp(0.0, 1.0),
            color: AppColors.brandBlue,
          ),
          child: Center(
            child: Text(
              '$pct%',
              style: _tabular(
                GoogleFonts.poppins(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double value;
  final Color color;
  _ProgressRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.border;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.value != value || old.color != color;
}
