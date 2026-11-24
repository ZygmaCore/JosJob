part of '../onboarding_page.dart';

// -------------------------------------------------------------------------
// Buttons (pill primary + ghost secondary), mirroring the auth page
// -------------------------------------------------------------------------
class _PillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _PillButton({
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: widget.busy,
      label: widget.busy ? '${widget.label}, please wait' : widget.label,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.975 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: enabled
              ? AppColors.brandBlue
              : AppColors.brandBlue.withValues(alpha: 0.45),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            customBorder: const StadiumBorder(),
            focusColor: AppColors.focus,
            child: SizedBox(
              height: 54,
              child: Center(
                child: widget.busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        widget.label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
