part of '../dashboard_page.dart';

// =========================================================================
// Focus-area filter chips for the coach browser: an "All" chip plus one per
// [_CoachFocus]. Wraps to multiple rows on narrow screens (no horizontal
// scroll). The active chip is filled brandBlue; a null [selected] = "All".
// =========================================================================
class _CoachFocusChips extends StatelessWidget {
  final _CoachFocus? selected;
  final ValueChanged<_CoachFocus?> onSelected;
  const _CoachFocusChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(context, null, 'All', selected == null),
        for (final f in _CoachFocus.values)
          _chip(context, f, f.label, selected == f),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    _CoachFocus? value,
    String label,
    bool active,
  ) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(100),
          focusColor: AppColors.focus,
          child: AnimatedContainer(
            duration: Duration(milliseconds: _reduceMotion(context) ? 0 : 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.brandBlue : AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: active ? AppColors.brandBlue : AppColors.border,
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : AppColors.body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
