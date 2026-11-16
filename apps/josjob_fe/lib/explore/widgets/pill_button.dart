part of '../explore_page.dart';

enum _BtnKind { filled, ghost, dense }

/// Pill button in three flavours: [filled] (primary brandBlue), [ghost]
/// (outlined) and [dense] (compact ghost for in-card actions). Mirrors the
/// auth/landing pill style.
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
    final filled = kind == _BtnKind.filled;
    final dense = kind == _BtnKind.dense;
    final fg = filled ? Colors.white : AppColors.brandBlue;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: filled ? AppColors.brandBlue : Colors.transparent,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.brandBlue),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          focusColor: AppColors.focus,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: dense ? 44 : 48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 18 : 24,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: fg,
                      fontSize: dense ? 14 : 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailing, color: fg, size: dense ? 17 : 19),
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
