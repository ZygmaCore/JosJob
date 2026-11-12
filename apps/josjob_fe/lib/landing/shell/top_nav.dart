part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Top navigation (fixed)
// -------------------------------------------------------------------------
class _TopNav extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback onLogin;
  const _TopNav({required this.onMenu, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Material(
      color: AppColors.bg.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.12),
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
                      onTap: item == 'Programs'
                          ? () => Navigator.of(context).pushNamed('/explore')
                          : null,
                    ),
                  ),
                const SizedBox(width: 12),
                const _LangToggle(),
                const SizedBox(width: 10),
                const _MoonToggle(),
                const SizedBox(width: 14),
                _PillButton('Log in', onPressed: onLogin),
              ] else
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu, color: AppColors.ink),
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
