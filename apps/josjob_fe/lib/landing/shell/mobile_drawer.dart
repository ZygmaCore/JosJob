part of '../landing_page_ascent.dart';

class _MobileDrawer extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onLogin;
  final VoidCallback onHowItWorks;
  const _MobileDrawer({
    required this.onCta,
    required this.onLogin,
    required this.onHowItWorks,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cotton,
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
                    icon: const Icon(Icons.close, color: AppColors.landingInk),
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
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.landingInk,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (item == 'Learn') {
                      Navigator.of(context).pushNamed('/explore');
                    } else if (item == 'Jobs') {
                      onCta();
                    } else {
                      onHowItWorks();
                    }
                  },
                ),
              const SizedBox(height: 12),
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
