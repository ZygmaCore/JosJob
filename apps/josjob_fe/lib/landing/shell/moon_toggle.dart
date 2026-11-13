part of '../landing_page_ascent.dart';

// ignore: unused_element
class _MoonToggle extends StatelessWidget {
  const _MoonToggle();
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dark mode (coming soon)',
      child: Semantics(
        button: true,
        label: 'Toggle dark mode',
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dark mode is coming soon'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          customBorder: const CircleBorder(),
          focusColor: AppColors.focus,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.dark_mode_outlined,
              size: 20,
              color: AppColors.body,
            ),
          ),
        ),
      ),
    );
  }
}
