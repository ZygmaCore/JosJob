part of '../auth_page.dart';

class _TermsCheck extends StatelessWidget {
  final bool value;
  final String? error;
  final ValueChanged<bool>? onChanged;
  const _TermsCheck({
    required this.value,
    required this.error,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CheckboxListTile(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('I understand that this is a preview.'),
        subtitle: const Text(
          'Terms and Privacy Policy are not yet published for this preview.',
        ),
      ),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Text(error!, style: const TextStyle(color: AppColors.danger)),
        ),
    ],
  );
}
