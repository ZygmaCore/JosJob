part of '../dashboard_page.dart';

// =========================================================================
// Sort control for the coach browser — a ghost pill that opens a popup menu
// of [_CoachSort] options, with a brandBlue check beside the current one.
// =========================================================================
class _CoachSortControl extends StatelessWidget {
  final _CoachSort value;
  final ValueChanged<_CoachSort> onChanged;
  const _CoachSortControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CoachSort>(
      initialValue: value,
      tooltip: 'Sort coaches',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        for (final s in _CoachSort.values)
          PopupMenuItem<_CoachSort>(
            value: s,
            child: Row(
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: s == value ? AppColors.brandBlue : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: s == value ? FontWeight.w700 : FontWeight.w500,
                    color: s == value ? AppColors.navy : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'Sort: ${value.label}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: AppColors.body,
              ),
              const SizedBox(width: 6),
              Text(
                value.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: AppColors.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
