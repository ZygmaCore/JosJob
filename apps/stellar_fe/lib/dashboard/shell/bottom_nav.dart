part of '../dashboard_page.dart';

// =========================================================================
// Mobile bottom navigation (<= 5 destinations). Active state = brandBlue icon
// + label + a filled icon and weight change, not colour alone.
// =========================================================================
class _BottomNav extends StatelessWidget {
  final List<_NavDest> dests;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const _BottomNav({
    required this.dests,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < dests.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    dest: dests[i],
                    active: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavDest dest;
  final bool active;
  final VoidCallback onTap;
  const _BottomNavItem({
    required this.dest,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.brandBlue : AppColors.body;
    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.tintBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(dest.icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              dest.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
