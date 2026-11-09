part of '../landing_page_ascent.dart';

/// Desktop: a centered vertical journey. Each milestone is a "station"
/// (numbered node + centered content); the spine is painted only in the
/// connectors between stations, so it never crosses a card.
class _DesktopSpine extends StatelessWidget {
  final ValueNotifier<double> fraction;
  final List<GlobalKey> milestoneKeys;
  final List<Widget> content;
  const _DesktopSpine({
    required this.fraction,
    required this.milestoneKeys,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[const _StartCap()];
    for (var i = 0; i < content.length; i++) {
      children.add(
        Padding(
          key: milestoneKeys[i],
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _StationNode(index: i, fraction: fraction, size: 58),
              const SizedBox(height: 32),
              content[i],
            ],
          ),
        ),
      );
      if (i != content.length - 1) {
        children.add(_Connector(index: i, fraction: fraction, height: 104));
      }
    }
    children
      ..add(
        _Connector(
          index: content.length - 1,
          fraction: fraction,
          height: 96,
          toSummit: true,
        ),
      )
      ..add(_Summit(fraction: fraction))
      ..add(const SizedBox(height: 24));
    return Column(children: children);
  }
}
