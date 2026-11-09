part of '../dashboard_page.dart';

// =========================================================================
// Base card container used everywhere: white surface, 18px radius, 1px border
// and the shared soft shadow. Optionally clips its child (for gradient bands).
// =========================================================================
class _DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;
  const _DashCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.clip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [_cardShadow],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
