part of '../dashboard_page.dart';

// =========================================================================
// Compact custom-painted bar chart: rounded-top bars over a subtle baseline,
// with weekday (or category) labels beneath. Static render — no animation.
// =========================================================================
class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _MiniBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    return Semantics(
      label: 'Bar chart',
      value: '${total.toStringAsFixed(1)} total across ${values.length} bars',
      child: SizedBox(
        height: 132,
        child: CustomPaint(
          painter: _MiniBarChartPainter(values: values, labels: labels),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MiniBarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  _MiniBarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelGap = 22.0; // reserved for weekday labels
    final chartH = size.height - labelGap;
    final maxV = values.reduce(math.max);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final n = values.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.5, 22.0);

    // Baseline.
    final baseline = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), baseline);

    final barPaint = Paint()..color = AppColors.brandBlue;
    final labelStyle = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.body,
    );

    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final h = (values[i] / safeMax) * (chartH - 8);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, chartH - h, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: slot);
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, chartH + (labelGap - tp.height) / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniBarChartPainter old) =>
      old.values != values || old.labels != labels;
}
