part of '../onboarding_page.dart';

// A checkbox row styled to match [_RadioTile]. Used for the "Internship?" flag.
class _CheckTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CheckTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? AppColors.tintBlue : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          focusColor: AppColors.focus,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.brandBlue : AppColors.border,
                width: selected ? 1.6 : 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 22,
                    color: selected ? AppColors.brandBlue : AppColors.body,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
