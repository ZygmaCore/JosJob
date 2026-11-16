part of '../onboarding_page.dart';

// Multi-select with search-to-add. Selected values show as removable chips;
// typing filters [suggestions] into a compact, capped results list (tap to
// add), and any free-text value can be added via the "Add <text>" row. This
// scales from a handful of options up to hundreds (e.g. countries) without a
// wall of chips: small lists (<= [_listAllThreshold]) list on focus, larger
// lists prompt the user to type. Selected values live in the caller-owned
// [selected] set; [onChanged] asks the flow to re-evaluate after each change.
class _MultiSelectInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final List<String> suggestions;
  final Set<String> selected;
  final VoidCallback onChanged;
  const _MultiSelectInput({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.hint = 'Search or add',
    this.icon,
    this.suggestions = const [],
  });

  @override
  State<_MultiSelectInput> createState() => _MultiSelectInputState();
}

class _MultiSelectInputState extends State<_MultiSelectInput> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  // Above this many suggestions we don't list them all on focus — the user
  // types to search instead, so big lists (e.g. countries) never flood.
  static const _listAllThreshold = 15;
  // Cap rendered matches so a broad query never builds hundreds of rows.
  static const _maxShown = 50;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _add(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return;
    setState(() {
      widget.selected.add(s);
      _query.clear();
    });
    widget.onChanged();
    // Keep focus so several values can be added in a row.
    _focus.requestFocus();
  }

  void _remove(String s) {
    setState(() => widget.selected.remove(s));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final ql = q.toLowerCase();

    final available = widget.suggestions.where(
      (s) => !widget.selected.contains(s),
    );
    final filtered =
        (ql.isEmpty
                ? available
                : available.where((s) => s.toLowerCase().contains(ql)))
            .toList();

    final large = widget.suggestions.length > _listAllThreshold;
    // Don't dump a large list on an empty query — prompt to type instead.
    final promptToType = ql.isEmpty && large;
    final shown = promptToType
        ? const <String>[]
        : filtered.take(_maxShown).toList();

    final canAddCustom =
        q.isNotEmpty &&
        !widget.selected.any((s) => s.toLowerCase() == ql) &&
        !widget.suggestions.any((s) => s.toLowerCase() == ql);

    final showResults =
        _focus.hasFocus && (promptToType || shown.isNotEmpty || canAddCustom);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label, optional: true),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in widget.selected)
                _RemovableChip(label: s, onRemove: () => _remove(s)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _LabeledField(
          label: '',
          hint: widget.hint,
          icon: widget.icon ?? Icons.search,
          controller: _query,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
        ),
        if (showResults) ...[
          const SizedBox(height: 8),
          // Tapping a suggestion must NOT unfocus the search field: on web/
          // desktop the TextField's default onTapOutside fires on pointer-down
          // and would rebuild this focus-gated panel away before the tile's
          // onTap runs (so nothing gets added — only the always-visible remove
          // chips work). TextFieldTapRegion marks the panel as "inside" the
          // field's tap group, keeping focus + the panel through the tap.
          TextFieldTapRegion(
            child: _SuggestionResults(
              promptToType: promptToType,
              shown: shown,
              totalMatches: filtered.length,
              query: q,
              canAddCustom: canAddCustom,
              onPick: _add,
            ),
          ),
        ],
      ],
    );
  }
}

// The compact, capped results panel shown under the search field while it has
// focus. Rows are ≥44px tall for comfortable tapping; the list scrolls inside a
// bounded height rather than growing the page.
class _SuggestionResults extends StatelessWidget {
  final bool promptToType;
  final List<String> shown;
  final int totalMatches;
  final String query;
  final bool canAddCustom;
  final ValueChanged<String> onPick;
  const _SuggestionResults({
    required this.promptToType,
    required this.shown,
    required this.totalMatches,
    required this.query,
    required this.canAddCustom,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 232),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            if (promptToType)
              _hint('Type to search…')
            else ...[
              for (final s in shown) _tile(label: s, onTap: () => onPick(s)),
              if (totalMatches > shown.length)
                _hint('Keep typing to narrow $totalMatches matches'),
            ],
            if (canAddCustom)
              _tile(
                label: 'Add "$query"',
                leading: Icons.add,
                accent: true,
                onTap: () => onPick(query),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String label,
    required VoidCallback onTap,
    IconData? leading,
    bool accent = false,
  }) {
    final color = accent ? AppColors.brandBlue : AppColors.ink;
    return InkWell(
      onTap: onTap,
      // Don't steal focus from the search field — keeps the panel open so the
      // user can add several values in a row.
      canRequestFocus: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18, color: color),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
    ),
  );
}
