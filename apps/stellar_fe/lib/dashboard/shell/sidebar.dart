part of '../dashboard_page.dart';

// =========================================================================
// Fixed-width desktop sidebar: brand mark, vertical nav, flexible spacer, and
// a user card with a logout affordance at the bottom.
// =========================================================================
class _Sidebar extends StatelessWidget {
  final List<_NavDest> dests;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final String name;
  final OnboardRole? role;
  const _Sidebar({
    required this.dests,
    required this.currentIndex,
    required this.onSelect,
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: _BrandMark(),
              ),
              const SizedBox(height: 28),
              for (var i = 0; i < dests.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _SidebarNavItem(
                  dest: dests[i],
                  active: i == currentIndex,
                  onTap: () => onSelect(i),
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

// Brand lockup reused by the sidebar and mobile top bar.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Atveti Stellar',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.brandBlue, size: 22),
          const SizedBox(width: 8),
          Text(
            'Atveti Stellar',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// User card + logout at the sidebar foot.
class _UserCard extends StatelessWidget {
  final String name;
  final OnboardRole? role;
  const _UserCard({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    final email = user?.email ?? '';
    // Show the real account email under the name; fall back to the role label.
    final subtitle = email.isNotEmpty ? email : _roleLabel(role);
    return Row(
      children: [
        _Avatar(name: name, size: 40, imageUrl: user?.avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.body),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Log out',
          child: IconButton(
            onPressed: () => _logout(context),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, size: 20, color: AppColors.body),
          ),
        ),
      ],
    );
  }
}
