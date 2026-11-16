part of '../landing_page_ascent.dart';

/// Below the desktop breakpoint: a left-rail vertical stepper. The rail runs
/// down the left gutter (never across content), so a single continuous line
/// reads cleanly here.
class _MobileSpine extends StatelessWidget {
  final ValueNotifier<double> fraction;
  final List<GlobalKey> milestoneKeys;
  final List<Widget> content;
  const _MobileSpine({
    required this.fraction,
    required this.milestoneKeys,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final vpad = _isMobile(context) ? 20.0 : 34.0;
    final rows = <Widget>[const SizedBox(height: 12)];
    for (var i = 0; i < content.length; i++) {
      rows.add(
        Padding(
          key: milestoneKeys[i],
          padding: EdgeInsets.symmetric(vertical: vpad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: Bp.railInset * 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _StationNode(index: i, fraction: fraction, size: 44),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: content[i]),
            ],
          ),
        ),
      );
    }
    rows.add(
      Padding(
        padding: EdgeInsets.only(top: vpad, bottom: 12),
        child: _Summit(fraction: fraction, desktop: false),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: fraction,
            builder: (context, f, _) =>
                CustomPaint(painter: _MobileSpinePainter(f)),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ],
    );
  }
}

class _MobileSpinePainter extends CustomPainter {
  final double fill;
  const _MobileSpinePainter(this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final x = Bp.railInset;
    final dot = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.fill;
    var y = 2.0;
    while (y <= size.height) {
      canvas.drawCircle(Offset(x, y), 1.7, dot);
      y += 9;
    }
    final fillH = size.height * fill.clamp(0.0, 1.0);
    if (fillH > 0) {
      final rect = Rect.fromLTWH(x - 1.5, 0, 3, size.height);
      final line = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, AppColors.heroBlue, AppColors.brandBlue],
        ).createShader(rect)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, 0), Offset(x, fillH), line);
    }
  }

  @override
  bool shouldRepaint(_MobileSpinePainter old) => old.fill != fill;
}
