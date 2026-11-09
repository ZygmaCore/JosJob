part of '../explore_page.dart';

/// Centres content and caps it at [Bp.maxContent] with responsive gutters —
/// the same measure used across the landing/auth/dashboard modules.
class _Bounded extends StatelessWidget {
  final Widget child;
  const _Bounded({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Bp.maxContent),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _gutter(context)),
          child: child,
        ),
      ),
    );
  }
}
