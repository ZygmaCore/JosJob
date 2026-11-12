part of '../quiz_page.dart';

/// Renders a single question: a "kind" tag, the prompt, and the appropriate
/// input (option list / free-text box / matching board). Controlled — all
/// answer state lives in the runner and flows in via the callbacks.
class _QuestionView extends StatelessWidget {
  final _Question question;

  // Multiple choice
  final String? selectedKey;
  final ValueChanged<String>? onSelectOption;

  // Open ended
  final TextEditingController? openController;
  final VoidCallback? onOpenChanged;

  // Matching
  final List<int>? rightOrder;
  final Map<int, int>? assignment;
  final void Function(int leftIndex, int rightOriginalIndex)? onAssign;
  final void Function(int leftIndex)? onClearMatch;

  const _QuestionView({
    required this.question,
    this.selectedKey,
    this.onSelectOption,
    this.openController,
    this.onOpenChanged,
    this.rightOrder,
    this.assignment,
    this.onAssign,
    this.onClearMatch,
  });

  (String, IconData) get _kind => switch (question) {
    _McqQuestion() => ('Multiple choice', Icons.radio_button_checked),
    _OpenQuestion() => ('Open response', Icons.edit_outlined),
    _MatchQuestion() => ('Matching', Icons.compare_arrows),
  };

  @override
  Widget build(BuildContext context) {
    final (kindLabel, kindIcon) = _kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _TagPill(
            kindLabel,
            fg: AppColors.brandBlue,
            bg: AppColors.tintBlue,
            icon: kindIcon,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          question.prompt,
          style: GoogleFonts.poppins(
            fontSize: _isMobile(context) ? 19 : 22,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 20),
        _input(context),
      ],
    );
  }

  Widget _input(BuildContext context) {
    final q = question;
    switch (q) {
      case _McqQuestion():
        return Column(
          children: [
            for (var i = 0; i < q.options.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _OptionTile(
                letter: q.options[i].key,
                text: q.options[i].text,
                state: selectedKey == q.options[i].key
                    ? _OptionState.selected
                    : _OptionState.idle,
                onTap: () => onSelectOption?.call(q.options[i].key),
              ),
            ],
          ],
        );
      case _OpenQuestion():
        return _OpenAnswerField(
          controller: openController!,
          hint: 'Type your answer…',
          onChanged: (_) => onOpenChanged?.call(),
        );
      case _MatchQuestion():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppColors.body,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tap a term on the left, then its match on the right.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MatchingBoard(
              pairs: q.pairs,
              rightOrder: rightOrder!,
              assignment: assignment!,
              onAssign: (l, r) => onAssign?.call(l, r),
              onClear: (l) => onClearMatch?.call(l),
            ),
          ],
        );
    }
  }
}
