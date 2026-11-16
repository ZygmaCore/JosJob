part of '../explore_page.dart';

/// Sort control — a PopupMenuButton styled as a stadium pill.
class _SortPill extends StatelessWidget {
  final _SortBy sort;
  final ValueChanged<_SortBy> onSort;
  const _SortPill({required this.sort, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortBy>(
      tooltip: 'Sort courses',
      initialValue: sort,
      onSelected: onSort,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final s in _SortBy.values)
          PopupMenuItem<_SortBy>(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == sort ? Icons.check : Icons.remove,
                  size: 18,
                  color: s == sort ? AppColors.brandBlue : Colors.transparent,
                ),
                const SizedBox(width: 10),
                Text(
                  s.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: s == sort ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18, color: AppColors.body),
            const SizedBox(width: 8),
            Text(
              _isMobile(context) ? sort.label : 'Sort: ${sort.label}',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: AppColors.body),
          ],
        ),
      ),
    );
  }
}
