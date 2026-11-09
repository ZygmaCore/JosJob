part of '../jobs_page.dart';

// =========================================================================
// Search input for the board. Filters the sample list client-side by role,
// company or location.
// =========================================================================
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search roles, companies or locations…',
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
        prefixIcon: const Icon(Icons.search, color: AppColors.body),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.brandBlue, 1.5),
      ),
    );
  }
}
