part of '../auth_page.dart';

// =========================================================================
// Shell — split brand panel + form (desktop) / centered card (mobile)
// =========================================================================
class _AuthShell extends StatelessWidget {
  final String brandHeadline;
  final String brandSub;
  final List<String> brandPoints;
  final Widget child;
  const _AuthShell({
    required this.brandHeadline,
    required this.brandSub,
    required this.brandPoints,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final wide = _wide(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: wide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _BrandPanel(
                    headline: brandHeadline,
                    sub: brandSub,
                    points: brandPoints,
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: _FormSide(showLogo: false, child: child),
                ),
              ],
            )
          : _FormSide(showLogo: true, child: child),
    );
  }
}
