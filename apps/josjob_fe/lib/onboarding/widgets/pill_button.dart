part of '../onboarding_page.dart';

// -------------------------------------------------------------------------
// Buttons (pill primary + ghost secondary), mirroring the auth page
// -------------------------------------------------------------------------
class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _PillButton({
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: busy,
      label: busy ? '$label, please wait' : label,
      child: Material(
        color: enabled
            ? AppColors.brandBlue
            : AppColors.brandBlue.withValues(alpha: 0.45),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const StadiumBorder(),
          focusColor: AppColors.focus,
          child: SizedBox(
            height: 54,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
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
    );
  }
}
