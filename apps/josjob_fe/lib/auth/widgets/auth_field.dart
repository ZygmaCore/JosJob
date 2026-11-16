part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Field — external label + rounded input, optional password toggle
// -------------------------------------------------------------------------
class _AuthField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscure;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  const _AuthField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.icon,
    this.focusNode,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
          cursorColor: AppColors.brandBlue,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            hintStyle: GoogleFonts.poppins(fontSize: 15, color: AppColors.body),
            helperStyle: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.body,
            ),
            errorStyle: GoogleFonts.poppins(fontSize: 12.5, color: _errorRed),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: AppColors.body),
            suffixIcon: widget.obscure
                ? _PasswordToggle(
                    obscured: _obscured,
                    onTap: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            filled: true,
            fillColor: widget.enabled ? Colors.white : const Color(0xFFEFF2F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.brandBlue, width: 1.6),
            errorBorder: _border(_errorRed),
            focusedErrorBorder: _border(_errorRed, width: 1.6),
            disabledBorder: _border(AppColors.border),
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
