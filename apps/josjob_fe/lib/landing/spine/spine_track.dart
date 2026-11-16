part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// The spine track — a metro-style progress line that threads the milestones.
// The line lives ONLY in the gaps between milestones (never behind content);
// nodes activate and connectors fill as you scroll.
// -------------------------------------------------------------------------
// ignore: unused_element
class _SpineTrack extends StatelessWidget {
  final ValueNotifier<double> fraction;
  final List<GlobalKey> milestoneKeys;
  const _SpineTrack({required this.fraction, required this.milestoneKeys});

  static const List<Widget> _content = [
    _StatsMilestone(),
    _GroupMilestone(_blended),
    _GroupMilestone(_audience, desktop: 4, tablet: 2, mobile: 1),
    _GroupMilestone(_compliance),
    _StepsMilestone(),
  ];

  @override
  Widget build(BuildContext context) {
    return _Bounded(
      child: _zig(context)
          ? _DesktopSpine(
              fraction: fraction,
              milestoneKeys: milestoneKeys,
              content: _content,
            )
          : _MobileSpine(
              fraction: fraction,
              milestoneKeys: milestoneKeys,
              content: _content,
            ),
    );
  }
}
