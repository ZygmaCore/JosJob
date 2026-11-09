part of '../landing_page_ascent.dart';

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _NavLink(this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      focusColor: AppColors.focus,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
