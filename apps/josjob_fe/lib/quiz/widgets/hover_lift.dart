part of '../quiz_page.dart';

/// Lifts its child slightly while the pointer hovers (desktop), passing the
/// hover flag to [builder] so borders/shadows can respond. Reduced-motion and
/// touch devices simply never lift. Mirrors the explore/landing convention.
class _HoverLift extends StatefulWidget {
  final Widget Function(bool hover) builder;
  const _HoverLift({required this.builder});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover && !_reduceMotion(context)
            ? const Offset(0, -0.014)
            : Offset.zero,
        duration: _anim(context, 180),
        curve: Curves.easeOut,
        child: widget.builder(_hover),
      ),
    );
  }
}
