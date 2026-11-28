part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Shared bits
// -------------------------------------------------------------------------
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
