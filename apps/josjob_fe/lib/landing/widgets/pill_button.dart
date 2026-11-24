part of '../landing_page_ascent.dart';

enum _BtnKind { filled, white, ghost, ghostLight }

class _PillButton extends StatefulWidget {
  final String label;
  final _BtnKind kind;
  final IconData? trailing;
  final VoidCallback onPressed;
  const _PillButton(
    this.label, {
    this.kind = _BtnKind.filled,
    this.trailing,
    required this.onPressed,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (widget.kind) {
      case _BtnKind.filled:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case _BtnKind.white:
        bg = AppColors.cotton;
        fg = AppColors.primary;
        break;
      case _BtnKind.ghost:
        bg = Colors.transparent;
        fg = AppColors.landingInk;
        side = const BorderSide(color: AppColors.rule2);
        break;
      case _BtnKind.ghostLight:
        bg = Colors.transparent;
        fg = AppColors.boardText;
        side = BorderSide(color: AppColors.boardText.withValues(alpha: .5));
        break;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.975 : 1,
        duration: _anim(context, 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: _hovered && widget.kind == _BtnKind.filled
              ? Color.lerp(bg, AppColors.primaryDeep, 0.07)
              : bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: _focused
                ? const BorderSide(color: AppColors.primary, width: 2)
                : side,
          ),
          elevation: _hovered ? 2 : 1,
          shadowColor: AppColors.landingInk.withValues(alpha: .14),
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (value) => setState(() => _hovered = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onFocusChange: (value) => setState(() => _focused = value),
            borderRadius: BorderRadius.circular(14),
            focusColor: AppColors.primaryDeep.withValues(alpha: .18),
            mouseCursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      Icon(widget.trailing, color: fg, size: 19),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
