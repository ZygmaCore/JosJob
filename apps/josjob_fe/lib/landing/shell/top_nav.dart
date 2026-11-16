part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Top navigation (fixed)
// -------------------------------------------------------------------------
class _TopNav extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback onLogin;
  final VoidCallback onHowItWorks;
  final VoidCallback onRegister;
  const _TopNav({
    required this.onMenu,
    required this.onLogin,
    required this.onHowItWorks,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Material(
      color: AppColors.paper.withValues(alpha: 0.98),
      elevation: 1,
      shadowColor: AppColors.landingInk.withValues(alpha: 0.08),
      child: _Bounded(
        child: SizedBox(
          height: Bp.navHeight,
          child: Row(
            children: [
              const _Logo(),
              if (!mobile) ...[
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in _navItems)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _NavLink(
                              item,
                              onTap: switch (item) {
                                'Learn' => () => Navigator.of(
                                  context,
                                ).pushNamed('/explore'),
                                'Jobs' => () => Navigator.of(
                                  context,
                                ).pushNamed('/register'),
                                _ => onHowItWorks,
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _PillButton('Log in', kind: _BtnKind.ghost, onPressed: onLogin),
                const SizedBox(width: 8),
                _PillButton('Get started', onPressed: onRegister),
              ] else
                const Spacer(),
              if (mobile)
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu, color: AppColors.landingInk),
                  tooltip: 'Open menu',
                  iconSize: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
