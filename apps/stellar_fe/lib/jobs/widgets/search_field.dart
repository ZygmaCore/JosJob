part of '../jobs_page.dart';

// =========================================================================
// Search input for debounced, server-side role and company discovery.
// =========================================================================
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final TextEditingController controller;
  const _SearchField({required this.onChanged, required this.controller});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      key: const ValueKey('jobs-search'),
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search roles, companies or keywords',
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
        prefixIcon: const Icon(Icons.search, color: AppColors.body),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.brandBlue, 1.5),
      ),
    );
  }
}
