part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Primary button (pill, loading state)
// -------------------------------------------------------------------------
class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: !widget.busy,
      liveRegion: widget.busy,
      label: widget.busy ? "${widget.label}, please wait" : null,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.975 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: widget.busy
              ? AppColors.brandBlue.withValues(alpha: 0.6)
              : AppColors.brandBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: widget.busy ? null : widget.onPressed,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            borderRadius: BorderRadius.circular(14),
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
