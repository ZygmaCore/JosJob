part of '../onboarding_page.dart';

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tintBlue,
      shape: StadiumBorder(
        side: const BorderSide(color: AppColors.brandBlue, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(width: 2),
            Semantics(
              button: true,
              label: 'Remove $label',
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
