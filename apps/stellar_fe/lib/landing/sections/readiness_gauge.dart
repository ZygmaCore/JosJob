part of '../landing_page_ascent.dart';

/// Skills-readiness gauge (climbs onboarding → certified).
class _ReadinessGauge extends StatelessWidget {
  final double value; // 0..1
  final bool compact;
  const _ReadinessGauge({required this.value, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 132.0 : 188.0;
    final frac = value.clamp(0.0, 1.0);
    final pct = (frac * 100).round();
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GaugePainter(frac),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Skills',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$pct%',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 24 : 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  'Certified',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.accent,
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

class _GaugePainter extends CustomPainter {
  final double frac;
  _GaugePainter(this.frac);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final track = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );
    final fill = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.accent, AppColors.brandBlue],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * frac.clamp(0.02, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.frac != frac;
}
