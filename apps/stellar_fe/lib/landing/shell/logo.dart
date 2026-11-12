part of '../landing_page_ascent.dart';

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'JosJob home',
    header: true,
    child: Image.asset(
      'assets/images/josjob_logo.png',
      width: 46,
      height: 46,
      fit: BoxFit.contain,
      semanticLabel: 'JosJob logo',
    ),
  );
}
