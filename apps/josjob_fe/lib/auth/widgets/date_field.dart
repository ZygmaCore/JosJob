part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Date field — external label + a tappable rounded box that opens a date
// picker. Styled to match [_AuthField] so it sits inline with the other form
// fields. Used for the (optional) date of birth on the create-account form.
// -------------------------------------------------------------------------
class _DateField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;
  const _DateField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    // Default the picker to a plausible adult birth year rather than today.
    final initial = value ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: enabled ? () => _pick(context) : null,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            isEmpty: v == null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.body,
              ),
              prefixIcon: Icon(icon, size: 20, color: AppColors.body),
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFEFF2F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _dateBorder(AppColors.border),
              enabledBorder: _dateBorder(AppColors.border),
              disabledBorder: _dateBorder(AppColors.border),
            ),
            child: v == null
                ? const SizedBox(height: 20)
                : Text(
                    _formatDob(v),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _dateBorder(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
