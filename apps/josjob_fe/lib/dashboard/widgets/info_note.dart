part of '../dashboard_page.dart';

// =========================================================================
// Tint-blue info callout with a leading icon. Used to explain a section.
// =========================================================================
class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.iconBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: AppColors.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
