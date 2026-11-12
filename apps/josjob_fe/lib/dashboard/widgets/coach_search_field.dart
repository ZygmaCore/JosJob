part of '../dashboard_page.dart';

// =========================================================================
// Search input for the coach browser. Filters the coach list client-side by
// name, expertise or tagline. Filled white field, radius-14 border with a
// brandBlue focus ring, and a clear-x once text is entered. Mirrors the
// Explore Courses search recipe for cross-module consistency.
// =========================================================================
class _CoachSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _CoachSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  OutlineInputBorder _border(Color c, {double w = 1.2}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.ink),
      cursorColor: AppColors.brandBlue,
      decoration: InputDecoration(
        hintText: 'Search coaches by name or expertise…',
        hintStyle: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.body),
        prefixIcon: const Icon(Icons.search, color: AppColors.body, size: 22),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                onPressed: onClear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 20, color: AppColors.body),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.brandBlue, w: 1.6),
      ),
    );
  }
}
