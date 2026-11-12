part of '../landing_page_ascent.dart';

class _MobileDrawer extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onLogin;
  const _MobileDrawer({required this.onCta, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Logo(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.ink),
                    tooltip: 'Close menu',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in _navItems)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 14,
                  title: Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (item == 'Programs') {
                      Navigator.of(context).pushNamed('/explore');
                    }
                  },
                ),
              const SizedBox(height: 12),
              const Row(
                children: [_LangToggle(), SizedBox(width: 12), _MoonToggle()],
              ),
              const SizedBox(height: 20),
              _PillButton(
                'Log in',
                kind: _BtnKind.ghost,
                onPressed: () {
                  Navigator.of(context).pop();
                  onLogin();
                },
              ),
              const SizedBox(height: 12),
              _PillButton(
                'Get started',
                onPressed: () {
                  Navigator.of(context).pop();
                  onCta();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
