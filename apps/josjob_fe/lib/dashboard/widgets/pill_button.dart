part of '../dashboard_page.dart';

// =========================================================================
// Fully-rounded pill button with three variants. Ripple feedback, a >=48dp
// touch target, and a proper Semantics button label.
// =========================================================================
enum _PillVariant { filled, tint, ghost }

class _PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final _PillVariant variant;
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = _PillVariant.filled,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (Color bg, Color fg, BorderSide side) = switch (widget.variant) {
      _PillVariant.filled => (
        AppColors.brandBlue,
        Colors.white,
        BorderSide.none,
      ),
      _PillVariant.tint => (
        AppColors.tintBlue,
        AppColors.brandBlue,
        BorderSide.none,
      ),
      _PillVariant.ghost => (
        Colors.transparent,
        AppColors.ink,
        const BorderSide(color: AppColors.border, width: 1.2),
      ),
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ],
    );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.975 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: side,
            ),
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              borderRadius: BorderRadius.circular(14),
              focusColor: AppColors.focus,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
