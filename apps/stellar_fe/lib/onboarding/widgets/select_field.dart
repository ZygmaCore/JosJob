part of '../onboarding_page.dart';

// Single-select dropdown styled to match [_LabeledField] (rounded 14 border,
// prefix icon, external label).
class _SelectField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData? icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _SelectField({
    required this.label,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
    this.value,
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
        DropdownButtonFormField<String>(
          // A selected/restored value that isn't in [items] (e.g. after the
          // list upgrades from the offline fallback to live backend data) would
          // trip DropdownButton's "exactly one match" assert. Drop it to null,
          // and key by [items] so the field remounts (re-seeding from the
          // guarded value) when the list is swapped under a selection.
          key: ValueKey(items),
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.body),
          style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.body,
                  ),
                ),
          decoration: InputDecoration(
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20, color: AppColors.body),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.brandBlue, width: 1.6),
          ),
          items: [
            for (final i in items)
              DropdownMenuItem(
                value: i,
                child: Text(i, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
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
