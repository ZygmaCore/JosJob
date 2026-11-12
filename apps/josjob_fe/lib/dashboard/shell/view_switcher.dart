part of '../dashboard_page.dart';

// =========================================================================
// Top-level product switcher — flips the whole dashboard between the two
// JosJob products: Learn (online learning) and Jobs (AI placement).
// A pill segmented control; the shell swaps its nav + content on change.
// =========================================================================
enum _DashView { learn, jobs }

class _ViewSwitcher extends StatelessWidget {
  final _DashView current;
  final ValueChanged<_DashView> onChanged;
  const _ViewSwitcher({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(_DashView.learn, Icons.school_outlined, 'Learn'),
          _seg(_DashView.jobs, Icons.work_outline, 'Jobs'),
        ],
      ),
    );
  }

  Widget _seg(_DashView view, IconData icon, String label) {
    final active = current == view;
    final fg = active ? Colors.white : AppColors.body;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(view),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
