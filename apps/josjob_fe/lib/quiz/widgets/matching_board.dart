part of '../quiz_page.dart';

/// Tap-to-pair matching question. Left column = prompts (fixed order); right
/// column = answers (shuffled via [rightOrder], holding original indices).
///
/// Interaction: tap a left row to select it, then tap a right row to link
/// them. A shared NUMBER badge (the left row's 1-based position) appears on
/// both linked rows, so the connection is legible without colour. Tap a linked
/// left row again to clear it.
///
/// Controlled: [assignment] maps leftIndex -> original right index and is owned
/// by the parent (a link is correct when leftIndex == original right index —
/// used by the parent when grading).
class _MatchingBoard extends StatefulWidget {
  final List<_MatchPair> pairs;
  final List<int> rightOrder;
  final Map<int, int> assignment;
  final void Function(int leftIndex, int rightOriginalIndex) onAssign;
  final void Function(int leftIndex) onClear;
  const _MatchingBoard({
    required this.pairs,
    required this.rightOrder,
    required this.assignment,
    required this.onAssign,
    required this.onClear,
  });

  @override
  State<_MatchingBoard> createState() => _MatchingBoardState();
}

class _MatchingBoardState extends State<_MatchingBoard> {
  int? _selectedLeft;

  void _tapLeft(int i) {
    if (widget.assignment.containsKey(i)) {
      widget.onClear(i);
      setState(() => _selectedLeft = null);
      return;
    }
    setState(() => _selectedLeft = _selectedLeft == i ? null : i);
  }

  void _tapRight(int originalIndex) {
    if (_selectedLeft == null) return;
    widget.onAssign(_selectedLeft!, originalIndex);
    setState(() => _selectedLeft = null);
  }

  /// The left row (if any) currently linked to a given original right index.
  int? _leftFor(int originalRight) {
    for (final e in widget.assignment.entries) {
      if (e.value == originalRight) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < widget.pairs.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _leftRow(i),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              for (var d = 0; d < widget.rightOrder.length; d++) ...[
                if (d > 0) const SizedBox(height: 10),
                _rightRow(widget.rightOrder[d]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _leftRow(int i) {
    final assigned = widget.assignment.containsKey(i);
    final selected = _selectedLeft == i;
    final border = selected
        ? AppColors.brandBlue
        : assigned
        ? AppColors.brandBlue.withValues(alpha: 0.5)
        : AppColors.border;
    return _cell(
      onTap: () => _tapLeft(i),
      border: border,
      selected: selected,
      leading: _slotBadge(assigned ? '${i + 1}' : null),
      text: widget.pairs[i].left,
      bold: true,
    );
  }

  Widget _rightRow(int originalIndex) {
    final linkedLeft = _leftFor(originalIndex);
    final border = linkedLeft != null
        ? AppColors.brandBlue.withValues(alpha: 0.5)
        : AppColors.border;
    return _cell(
      onTap: () => _tapRight(originalIndex),
      border: border,
      selected: false,
      leading: _slotBadge(linkedLeft != null ? '${linkedLeft + 1}' : null),
      text: widget.pairs[originalIndex].right,
      bold: false,
    );
  }

  Widget _slotBadge(String? label) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: label == null ? Colors.transparent : AppColors.brandBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: label == null ? AppColors.border : AppColors.brandBlue,
          width: 1.4,
        ),
      ),
      child: label == null
          ? null
          : Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _cell({
    required VoidCallback onTap,
    required Color border,
    required bool selected,
    required Widget leading,
    required String text,
    required bool bold,
  }) {
    return Material(
      color: selected ? AppColors.tintBlue : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        focusColor: AppColors.focus,
        child: AnimatedContainer(
          duration: _anim(context, 140),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 2 : 1.4),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
