part of '../landing_page_ascent.dart';

/// Transparent JosJob mark used as the hero's primary visual.
class _Basecamp extends StatelessWidget {
  const _Basecamp();

  @override
  Widget build(BuildContext context) {
    final desktop = _zig(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: desktop ? 480 : 360),
        child: SizedBox(
          width: double.infinity,
          height: desktop ? 440 : 320,
          child: Image.asset(
            'assets/images/josjob_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'JosJob logo',
          ),
        ),
      ),
    );
  }
}
