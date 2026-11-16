part of '../dashboard_page.dart';

// =========================================================================
// Fully-rounded pill button with three variants. Ripple feedback, a >=48dp
// touch target, and a proper Semantics button label.
// =========================================================================
enum _PillVariant { filled, tint, ghost }

class _PillButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, BorderSide side) = switch (variant) {
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
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
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

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: bg,
          shape: StadiumBorder(side: side),
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            focusColor: AppColors.focus,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
