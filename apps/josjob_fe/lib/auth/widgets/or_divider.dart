part of '../auth_page.dart';

// -------------------------------------------------------------------------
// "or continue with" + social buttons (decorative — no backend yet)
// -------------------------------------------------------------------------
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'or continue with',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}
