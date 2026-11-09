part of '../onboarding_page.dart';

// =========================================================================
// Scrollable content shell — centers a max-width column
// =========================================================================
class _ContentShell extends StatelessWidget {
  final Widget child;
  const _ContentShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final compact = _compact(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 32,
        compact ? 8 : 16,
        compact ? 20 : 32,
        24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: child,
        ),
      ),
    );
  }
}
