part of '../dashboard_page.dart';

// =========================================================================
// Top bar. Desktop: page title, "Ask AI", notification button + badge.
// Mobile: menu button, title, "Ask AI", notification button. The AI assistant
// lives here universally (it is no longer a nav destination).
// =========================================================================
class _TopBar extends StatelessWidget {
  final String title;
  final bool mobile;
  final VoidCallback? onMenu;
  const _TopBar({required this.title, required this.mobile, this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 24),
          child: mobile ? _buildMobile(context) : _buildDesktop(context),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          button: true,
          label: 'Documents',
          child: IconButton(
            onPressed: () => _documents(context),
            tooltip: 'Documents',
            icon: const Icon(
              Icons.folder_shared_outlined,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _PillButton(
          label: 'Ask AI',
          icon: Icons.auto_awesome,
          variant: _PillVariant.tint,
          onPressed: () => _demoAction(context),
        ),
        const SizedBox(width: 8),
        const _NotificationButton(),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Open menu',
          child: IconButton(
            onPressed: onMenu,
            tooltip: 'Menu',
            icon: const Icon(Icons.menu, color: AppColors.ink),
          ),
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Documents',
          child: IconButton(
            onPressed: () => _documents(context),
            tooltip: 'Documents',
            icon: const Icon(
              Icons.folder_shared_outlined,
              color: AppColors.ink,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Ask AI',
          child: IconButton(
            onPressed: () => _demoAction(context),
            tooltip: 'Ask AI',
            icon: const Icon(Icons.auto_awesome, color: AppColors.brandBlue),
          ),
        ),
        const _NotificationButton(),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications, 3 unread',
      child: IconButton(
        onPressed: () => _demoAction(context),
        tooltip: 'Notifications',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined, color: AppColors.ink),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
