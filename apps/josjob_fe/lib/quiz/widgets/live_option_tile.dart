part of '../quiz_page.dart';

/// A game-show style answer tile for the live quiz. Fills its grid cell. Each
/// tile owns a distinct colour AND shape glyph AND letter, so it is
/// identifiable without relying on colour. On reveal, the correct tile stays
/// vivid with a check; the rest fade, and the learner's wrong pick is marked.
class _LiveOptionTile extends StatelessWidget {
  final int index; // 0..3 -> palette entry
  final _Option option;
  final bool selected;
  final bool dimmed; // another option is selected, this one isn't
  final bool revealed;
  final bool isCorrect;
  final VoidCallback? onTap;
  const _LiveOptionTile({
    required this.index,
    required this.option,
    required this.selected,
    required this.dimmed,
    required this.revealed,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = _livePalette[index % _livePalette.length];
    final bool faded = revealed ? !isCorrect : dimmed;
    final mobile = _isMobile(context);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${option.key}. ${option.text}',
      child: Opacity(
        opacity: faded ? 0.42 : 1,
        child: Material(
          color: pal.bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.white24,
            child: AnimatedContainer(
              duration: _anim(context, 160),
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 14 : 18,
                vertical: mobile ? 12 : 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Row(
                children: [
                  Icon(pal.shape, color: pal.fg, size: mobile ? 22 : 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: mobile ? 15.5 : 18,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: pal.fg,
                      ),
                    ),
                  ),
                  if (revealed && isCorrect) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, color: pal.fg, size: 24),
                  ] else if (revealed && selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.close, color: pal.fg, size: 24),
                  ] else if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.radio_button_checked, color: pal.fg, size: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
