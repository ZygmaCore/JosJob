part of '../dashboard_page.dart';

// =========================================================================
// Base card container used everywhere: white surface, 18px radius, 1px border
// and the shared soft shadow.
// =========================================================================
class _DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _DashCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
