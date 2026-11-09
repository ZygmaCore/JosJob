part of '../auth_page.dart';

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue with $label',
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.border, width: 1.2),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          focusColor: AppColors.focus,
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
