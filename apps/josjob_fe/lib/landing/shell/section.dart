part of '../landing_page_ascent.dart';

class _Section extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Section({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final v = _isMobile(context) ? 52.0 : 84.0;
    return ColoredBox(
      color: color,
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: v),
          child: child,
        ),
      ),
    );
  }
}
