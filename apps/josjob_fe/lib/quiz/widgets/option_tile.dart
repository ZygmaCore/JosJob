part of '../quiz_page.dart';

/// Visual state of a multiple-choice option. [selected] is used while
/// answering; [correct]/[wrong] are used in the answer review, where colour is
/// always backed by a check / cross icon (never colour alone).
enum _OptionState { idle, selected, correct, wrong }

/// A full-width multiple-choice option: a letter chip + label with a clear
/// selected / correct / incorrect treatment. Comfortably above the 44px target.
class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap; // null => locked (review mode)
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    final (
      Color border,
      Color bg,
      Color chipBg,
      Color chipFg,
    ) = switch (state) {
      _OptionState.idle => (
        AppColors.border,
        AppColors.surface,
        AppColors.tintBlue,
        AppColors.brandBlue,
      ),
      _OptionState.selected => (
        AppColors.brandBlue,
        AppColors.tintBlue,
        AppColors.brandBlue,
        Colors.white,
      ),
      _OptionState.correct => (
        AppColors.iconGreen,
        AppColors.tintGreen,
        AppColors.iconGreen,
        Colors.white,
      ),
      _OptionState.wrong => (red, const Color(0xFFFDEBEB), red, Colors.white),
    };

    final IconData? mark = switch (state) {
      _OptionState.correct => Icons.check_circle,
      _OptionState.wrong => Icons.cancel,
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      selected: state == _OptionState.selected,
      label: '$letter. $text',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          focusColor: AppColors.focus,
          child: AnimatedContainer(
            duration: _anim(context, 150),
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: border,
                width: state == _OptionState.idle ? 1.4 : 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    letter,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: chipFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (mark != null) ...[
                  const SizedBox(width: 10),
                  Icon(mark, size: 22, color: border),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
