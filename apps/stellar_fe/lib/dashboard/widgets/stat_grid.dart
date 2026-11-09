part of '../dashboard_page.dart';

// =========================================================================
// Responsive grid of stat cards: 4-up desktop, 2-up tablet, and 1-2-up on
// mobile depending on width. Uses a Wrap driven by LayoutBuilder.
// =========================================================================
class _StatGrid extends StatelessWidget {
  final List<_StatData> stats;
  const _StatGrid(this.stats);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 880
            ? 4
            : w >= 560
            ? 2
            : w >= 360
            ? 2
            : 1;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats) SizedBox(width: itemW, child: _StatCard(s)),
          ],
        );
      },
    );
  }
}
