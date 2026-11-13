part of '../landing_page_ascent.dart';

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'JosJob home',
    header: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/josjob_logo.png',
          width: 42,
          height: 42,
          fit: BoxFit.contain,
          semanticLabel: 'JosJob logo',
        ),
        const SizedBox(width: 10),
        Text(
          'JosJob',
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    ),
  );
}
