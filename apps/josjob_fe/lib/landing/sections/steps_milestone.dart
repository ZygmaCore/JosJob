part of '../landing_page_ascent.dart';

class _StepsMilestone extends StatelessWidget {
  const _StepsMilestone();

  @override
  Widget build(BuildContext context) {
    final desktop = _zig(context);
    final header = Column(
      children: [
        const _Eyebrow('MILESTONE 05 · HOW IT WORKS'),
        const SizedBox(height: 14),
        _Title('How an JosJob program runs', center: true),
      ],
    );
    final stepList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (n, t, b) in _steps) ...[
          _StepRow(n, t, b),
          const SizedBox(height: 14),
        ],
      ],
    );
    if (!desktop) {
      return Column(
        children: [
          header,
          const SizedBox(height: 24),
          stepList,
          const SizedBox(height: 28),
          const Center(child: _PortalMock()),
        ],
      );
    }
    return Column(
      children: [
        header,
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 6, child: stepList),
            const SizedBox(width: 40),
            const Expanded(flex: 5, child: Center(child: _PortalMock())),
          ],
        ),
      ],
    );
  }
}
