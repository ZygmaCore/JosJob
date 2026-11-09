part of '../onboarding_page.dart';

// =========================================================================
// Page transition — directional slide + fade, reduced-motion safe
// =========================================================================
class _Transitioner extends StatelessWidget {
  final bool forward;
  final bool reduceMotion;
  final Widget child;
  const _Transitioner({
    required this.forward,
    required this.reduceMotion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        final incoming = child.key == this.child.key;
        final dir = forward ? 1.0 : -1.0;
        final begin = Offset(incoming ? 0.06 * dir : -0.06 * dir, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: child,
    );
  }
}
