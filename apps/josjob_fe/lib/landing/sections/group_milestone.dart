part of '../landing_page_ascent.dart';

class _GroupMilestone extends StatelessWidget {
  final _Group group;
  final int desktop, tablet, mobile;
  const _GroupMilestone(
    this.group, {
    this.desktop = 3,
    this.tablet = 3,
    this.mobile = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Eyebrow(group.eyebrow),
        const SizedBox(height: 14),
        _Title(group.title, center: true),
        const SizedBox(height: 32),
        _CardGrid(
          desktop: desktop,
          tablet: tablet,
          mobile: mobile,
          children: [for (final it in group.items) _ProgramCard(it)],
        ),
      ],
    );
  }
}
