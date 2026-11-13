part of '../quiz_page.dart';

enum _BtnKind {
  filled, // primary brandBlue
  ghost, // outlined brandBlue
  dense, // compact ghost for in-card actions
  light, // white fill / navy text — for dark hero + gradient surfaces
}

/// Pill button used across the module. Meets the 48px (44px dense) touch
/// target, exposes a single accessible node, and shows a visible focus ring.
class _PillButton extends StatelessWidget {
  final String label;
  final _BtnKind kind;
  final IconData? leading;
  final IconData? trailing;
  final bool expand; // stretch to the available width
  final VoidCallback? onPressed;
  const _PillButton(
    this.label, {
    this.kind = _BtnKind.filled,
    this.leading,
    this.trailing,
    this.expand = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final filled = kind == _BtnKind.filled;
    final light = kind == _BtnKind.light;
    final dense = kind == _BtnKind.dense;
    final disabled = onPressed == null;

    final Color bg = filled
        ? AppColors.brandBlue
        : light
        ? Colors.white
        : Colors.transparent;
    final Color fg = filled
        ? Colors.white
        : light
        ? AppColors.navy
        : AppColors.brandBlue;
    final BorderSide side = (filled || light)
        ? BorderSide.none
        : const BorderSide(color: AppColors.brandBlue);

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: label,
        child: Material(
          color: bg,
          shape: StadiumBorder(side: side),
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
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      Icon(leading, color: fg, size: dense ? 17 : 19),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: fg,
                          fontSize: dense ? 14 : 15.5,
                          fontWeight: FontWeight.w600,
                        ),
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
      ),
    );
  }
}
