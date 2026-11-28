part of '../auth_page.dart';

class _FormSide extends StatelessWidget {
  final bool showLogo;
  final Widget child;
  const _FormSide({required this.showLogo, required this.child});

  @override
  Widget build(BuildContext context) {
    final compact = _compact(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 32,
              18,
              compact ? 12 : 24,
              4,
            ),
            child: Row(
              children: [
                if (showLogo) const _BrandLogo(dark: true) else const Spacer(),
                const Spacer(),
                _BackToSite(onTap: () => _backToSite(context)),
              ],
            ),
          ),
          Expanded(
            // Center the form vertically in the remaining space. A bare Center
            // inside a SingleChildScrollView can't do this — the scroll view
            // hands its child unbounded height, so Center shrink-wraps and pins
            // the form to the top. Forcing the content to be at least as tall as
            // the viewport (minus padding) lets Center center it, while still
            // allowing the page to scroll when the form outgrows the space.
            child: LayoutBuilder(
              builder: (context, constraints) {
                const vPad = 16.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 20 : 32,
                    vertical: vPad,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - vPad * 2,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
