part of '../onboarding_page.dart';

class _LabeledField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData? icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool readOnly;
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          readOnly: readOnly,
          textInputAction: textInputAction,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: readOnly ? AppColors.body : AppColors.ink,
          ),
          cursorColor: AppColors.brandBlue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 15, color: AppColors.body),
            errorStyle: GoogleFonts.poppins(fontSize: 12.5, color: _errorRed),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20, color: AppColors.body),
            filled: true,
            fillColor: readOnly ? AppColors.bg : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.brandBlue, width: 1.6),
            errorBorder: _border(_errorRed),
            focusedErrorBorder: _border(_errorRed, width: 1.6),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
