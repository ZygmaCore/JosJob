part of '../explore_page.dart';

/// The catalog search field — copies the auth field recipe (filled white,
/// radius-14 border, brandBlue focus) with a clear-x when non-empty.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
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
      style: GoogleFonts.poppins(fontSize: 15.5, color: AppColors.ink),
      cursorColor: AppColors.brandBlue,
      decoration: InputDecoration(
        hintText: 'Search courses by title, field or category…',
        hintStyle: GoogleFonts.poppins(fontSize: 15.5, color: AppColors.body),
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
          vertical: 18,
        ),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.brandBlue, w: 1.6),
      ),
    );
  }
}
