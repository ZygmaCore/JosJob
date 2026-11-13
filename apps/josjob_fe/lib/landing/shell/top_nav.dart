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
      color: AppColors.paper.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: AppColors.landingInk.withValues(alpha: 0.12),
      child: _Bounded(
        child: SizedBox(
          height: Bp.navHeight,
          child: Row(
            children: [
              const _Logo(),
              const Spacer(),
              if (!mobile) ...[
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
                const SizedBox(width: 12),
                const SizedBox(width: 14),
                _PillButton('Log in', onPressed: onLogin),
                const SizedBox(width: 8),
                _PillButton('Sign up', onPressed: onRegister),
              ] else
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
