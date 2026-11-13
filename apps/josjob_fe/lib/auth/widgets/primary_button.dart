part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Primary button (pill, loading state)
// -------------------------------------------------------------------------
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      liveRegion: busy,
      label: busy ? '$label, please wait' : label,
      child: Material(
        color: busy
            ? AppColors.brandBlue.withValues(alpha: 0.6)
            : AppColors.brandBlue,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: busy ? null : onPressed,
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
