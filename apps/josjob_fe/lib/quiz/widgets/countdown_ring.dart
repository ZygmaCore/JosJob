part of '../quiz_page.dart';

/// A circular countdown: an arc that depletes as time runs out, with the
/// remaining seconds shown in tabular figures at the centre. Turns amber then
/// red in the final stretch. The value is driven by the parent's 1s ticks, so
/// this widget stays a pure painter (no internal timer).
class _CountdownRing extends StatelessWidget {
  final int remaining;
  final int total;
  const _CountdownRing({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final fraction = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final Color color = remaining <= 5
        ? const Color(0xFFDC2626)
        : remaining <= 10
        ? AppColors.orange
        : AppColors.brandBlue;

    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: '$remaining seconds remaining',
        liveRegion: true,
        child: CustomPaint(
          painter: _CountdownPainter(fraction: fraction, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$remaining',
                  style: _tabular(
                    GoogleFonts.poppins(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  'sec',
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double fraction; // 1 -> full, 0 -> empty
  final Color color;
  const _CountdownPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 9) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = AppColors.border;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = color;

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
  bool shouldRepaint(_CountdownPainter old) =>
      old.fraction != fraction || old.color != color;
}
