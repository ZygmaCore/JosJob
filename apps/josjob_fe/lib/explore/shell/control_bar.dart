part of '../explore_page.dart';

// =========================================================================
// Control bar — result count + sort. Industry (the only facet) has its own
// tile row above; there are no secondary filters to collapse into a sheet.
// =========================================================================
class _ControlBar extends StatelessWidget {
  final int total;
  final String query;
  final _SortBy sort;
  final ValueChanged<_SortBy> onSort;
  const _ControlBar({
    required this.total,
    required this.query,
    required this.sort,
    required this.onSort,
  });

  String get _countLabel {
    if (query.trim().isNotEmpty) {
      return '$total ${total == 1 ? 'result' : 'results'} for "${query.trim()}"';
    }
    return '$total ${total == 1 ? 'course' : 'courses'}';
  }

  @override
  Widget build(BuildContext context) {
    final count = Semantics(
      liveRegion: true,
      child: Text(
        _countLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );

    return Row(
      children: [
        Expanded(child: count),
        const SizedBox(width: 12),
        _SortPill(sort: sort, onSort: onSort),
      ],
    );
  }
}
