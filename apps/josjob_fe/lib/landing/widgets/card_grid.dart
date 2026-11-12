part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Utilities
// -------------------------------------------------------------------------
class _CardGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktop, tablet, mobile;
  static const double gap = 20;
  const _CardGrid({
    required this.children,
    this.desktop = 4,
    this.tablet = 2,
    this.mobile = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w < 768 ? mobile : (w < Bp.desktop ? tablet : desktop);
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: itemW, child: child),
          ],
        );
      },
    );
  }
}
