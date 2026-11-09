part of '../landing_page_ascent.dart';

class _Title extends StatelessWidget {
  final String text;
  final bool center;
  const _Title(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: _h2s(context),
      ),
    );
  }
}
