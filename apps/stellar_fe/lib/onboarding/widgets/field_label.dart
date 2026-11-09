part of '../onboarding_page.dart';

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final bool optional;
  const _FieldLabel(this.text, {this.required = false, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (required)
          Text(
            ' *',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _errorRed,
            ),
          ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
          ),
        ],
      ],
    );
  }
}
