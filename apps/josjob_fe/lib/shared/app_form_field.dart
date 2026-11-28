import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

OutlineInputBorder _border(Color color, {double width = 1.2}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

/// The labeled input treatment used by the auth and onboarding forms.
class AppFormField extends StatelessWidget {
  final String label;
  final String? hint, helper;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon, suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool enabled;

  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      const SizedBox(height: 7),
      Semantics(
        label: label,
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          validator: validator,
          maxLines: maxLines,
          minLines: maxLines,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          textInputAction:
              textInputAction ??
              (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
          cursorColor: AppColors.brandBlue,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helper,
            helperMaxLines: 3,
            errorMaxLines: 3,
            counterText: '',
            hintStyle: GoogleFonts.poppins(fontSize: 15, color: AppColors.body),
            helperStyle: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.body,
            ),
            errorStyle: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.danger,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixIconColor: AppColors.body,
            suffixIconColor: AppColors.body,
            filled: true,
            fillColor: enabled ? AppColors.surface : const Color(0xFFEFF2F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.brandBlue, width: 1.6),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, width: 1.6),
            disabledBorder: _border(AppColors.border),
          ),
        ),
      ),
    ],
  );
}

/// Keep form dialogs and the date/time picker input modes on the same palette
/// and typography as the page fields, without changing the app-wide theme.
ThemeData appFormTheme(BuildContext context) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.navy),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      focusedBorder: _border(AppColors.brandBlue, width: 1.6),
      errorBorder: _border(AppColors.danger),
      focusedErrorBorder: _border(AppColors.danger, width: 1.6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.surface,
      shape: shape,
      dialBackgroundColor: AppColors.bg,
      dialHandColor: AppColors.brandBlue,
      dialTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.ink,
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.tintBlue
            : AppColors.bg,
      ),
      hourMinuteTextColor: AppColors.navy,
      hourMinuteTextStyle: GoogleFonts.poppins(
        fontSize: 52,
        fontWeight: FontWeight.w500,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.tintBlue
            : AppColors.surface,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandBlue
            : AppColors.body,
      ),
      dayPeriodTextStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      dayPeriodBorderSide: const BorderSide(color: AppColors.border),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget appFormDialog(BuildContext context, Widget? child) =>
    Theme(data: appFormTheme(context), child: child!);
