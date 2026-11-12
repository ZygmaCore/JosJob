part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Spine segments — the line only ever appears here, in the gaps.
// -------------------------------------------------------------------------
class _StartCap extends StatelessWidget {
  const _StartCap();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 58,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpineSegmentPainter(fill: 1, showTrack: false, fadeTop: true),
      ),
    );
  }
}
