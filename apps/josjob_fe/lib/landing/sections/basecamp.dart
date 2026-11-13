part of '../landing_page_ascent.dart';

/// The supplied JosJob mascot is the hero's single product visual.
class _Basecamp extends StatelessWidget {
  const _Basecamp();

  @override
  Widget build(BuildContext context) {
    final size = _zig(context) ? 430.0 : 300.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size, maxHeight: size),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            'assets/images/josjob_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'JosJob mascot logo',
          ),
        ),
      ),
    );
  }
}
