part of '../dashboard_page.dart';

// =========================================================================
// One sidebar nav entry. Active state = tintBlue pill + brandBlue icon/label
// + a leading indicator bar (never colour alone).
// =========================================================================
class _SidebarNavItem extends StatelessWidget {
  final _NavDest dest;
  final bool active;
  final VoidCallback onTap;
  const _SidebarNavItem({
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
      child: Material(
        color: active ? AppColors.tintBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          focusColor: AppColors.focus,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: _reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: 3,
                  height: active ? 20 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(dest.icon, size: 21, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dest.label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? AppColors.brandBlue : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
