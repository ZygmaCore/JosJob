part of '../dashboard_page.dart';

// =========================================================================
// Mobile navigation drawer — mirrors the sidebar (brand, user, full nav list,
// logout). Selecting a destination closes the drawer.
// =========================================================================
class _MobileDrawer extends StatelessWidget {
  final List<_NavDest> dests;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final String name;
  final OnboardRole? role;
  const _MobileDrawer({
    required this.dests,
    required this.currentIndex,
    required this.onSelect,
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _BrandMark(),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Close menu',
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: AppColors.body),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < dests.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _SidebarNavItem(
                  dest: dests[i],
                  active: i == currentIndex,
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onSelect(i);
                  },
                ),
              ],
              const Spacer(),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              _UserCard(name: name, role: role),
            ],
          ),
        ),
      ),
    );
  }
}
