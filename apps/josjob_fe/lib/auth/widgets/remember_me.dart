part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Remember me + Terms
// -------------------------------------------------------------------------
class _RememberMe extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _RememberMe({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // MergeSemantics + the padded Checkbox announce as one labelled, toggleable
    // control ("Remember me, checkbox, [checked]"); the label is a bonus target.
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckBox(value: value, onChanged: onChanged),
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                'Remember me',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
