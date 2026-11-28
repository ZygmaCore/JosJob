part of '../explore_page.dart';

/// Sizes columns from the available content width. Cards grow with their text.
class _CourseGrid extends StatelessWidget {
  final List<_Course> courses;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<_Course> onOpen;
  const _CourseGrid({
    required this.courses,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _ResponsiveGrid(
      children: [
        for (final c in courses)
          _CourseCard(
            course: c,
            saved: saved.contains(c.id),
            onSave: () => onSave(c.id),
            onOpen: () => onOpen(c),
          ),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveGrid({required this.children});

  static const double _gap = 20;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + _gap) / 340).floor().clamp(1, 3);
        final itemW = (c.maxWidth - _gap * (cols - 1)) / cols;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final child in children) SizedBox(width: itemW, child: child),
          ],
        );
      },
    );
  }
}
