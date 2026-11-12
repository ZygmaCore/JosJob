part of '../explore_page.dart';

// =========================================================================
// Primary industry filter — single-select tinted tiles (horizontal scroll on
// small screens). "All Fields" + one tile per industry present in the catalog,
// each with a count.
// =========================================================================
class _IndustryFilter extends StatelessWidget {
  final List<String> names;
  final String? selected;
  final int Function(String?) countFor;
  final ValueChanged<String?> onSelect;
  const _IndustryFilter({
    required this.names,
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _IndustryTile(
        label: 'All Fields',
        icon: _generalVisual.icon,
        color: _generalVisual.iconColor,
        tint: _generalVisual.tint,
        count: countFor(null),
        selected: selected == null,
        onTap: () => onSelect(null),
      ),
      for (final name in names)
        Builder(
          builder: (_) {
            final v = _industryVisual(name);
            return _IndustryTile(
              label: v.short,
              icon: v.icon,
              color: v.iconColor,
              tint: v.tint,
              count: countFor(name),
              selected: selected == name,
              onTap: () => onSelect(name),
            );
          },
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (var k = 0; k < tiles.length; k++)
            Padding(
              padding: EdgeInsets.only(right: k == tiles.length - 1 ? 0 : 12),
              child: tiles[k],
            ),
        ],
      ),
    );
  }
}

class _IndustryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _IndustryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count courses',
      child: Material(
        color: selected ? AppColors.surface : tint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: AppColors.focus,
          child: AnimatedContainer(
            duration: _anim(context, 160),
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.brandBlue : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '$count courses',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.brandBlue,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
