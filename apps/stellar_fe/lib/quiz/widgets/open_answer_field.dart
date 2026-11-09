part of '../quiz_page.dart';

/// A multi-line free-text answer box for open-ended questions, with a visible
/// label-style hint and helper text. Purely an input; the review screen renders
/// the submitted text separately.
class _OpenAnswerField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  const _OpenAnswerField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.45,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: 14.5,
              color: AppColors.body,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.brandBlue,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 15,
              color: AppColors.body,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Answer in your own words — a reasonable response counts.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.body,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
