part of '../landing_page_ascent.dart';

class _HoverLift extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  const _HoverLift({required this.builder});
  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final lift = _hover && !_reduceMotion(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: _anim(context, 200),
        transform: Matrix4.translationValues(0, lift ? -4 : 0, 0),
        child: widget.builder(_hover),
      ),
    );
  }
}
