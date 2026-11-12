part of '../landing_page_ascent.dart';

enum _BtnKind { filled, white, ghost, ghostLight }

class _PillButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    late Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case _BtnKind.filled:
        bg = AppColors.brandBlue;
        fg = Colors.white;
        break;
      case _BtnKind.white:
        bg = Colors.white;
        fg = AppColors.brandBlue;
        break;
      case _BtnKind.ghost:
        bg = Colors.transparent;
        fg = AppColors.brandBlue;
        side = const BorderSide(color: AppColors.brandBlue);
        break;
      case _BtnKind.ghostLight:
        bg = Colors.transparent;
        fg = Colors.white;
        side = const BorderSide(color: Colors.white54);
        break;
    }
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: side),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          focusColor: AppColors.focus,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: fg,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailing, color: fg, size: 19),
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
