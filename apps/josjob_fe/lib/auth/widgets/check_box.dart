part of '../auth_page.dart';

class _CheckBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _CheckBox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Padded target gives the checkbox a 48px hit area (meets the 44px minimum).
    return Checkbox(
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      activeColor: AppColors.brandBlue,
      side: const BorderSide(color: AppColors.body, width: 1.6),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}
