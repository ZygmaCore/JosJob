part of '../auth_page.dart';

class _PasswordToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onTap;
  const _PasswordToggle({required this.obscured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = obscured ? 'Show password' : 'Hide password';
    // IconButton's tooltip already provides the accessible label; a wrapping
    // Semantics(button) would double-announce, so we rely on the tooltip.
    return IconButton(
      onPressed: onTap,
      tooltip: label,
      splashRadius: 22,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppColors.body,
      ),
    );
  }
}
