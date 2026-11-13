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
      focusColor: AppColors.primaryDeep,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'General Sans',
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: AppColors.landingInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
