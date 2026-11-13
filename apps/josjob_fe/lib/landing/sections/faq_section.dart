part of '../landing_page_ascent.dart';

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    final desktop = _zig(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Questions'),
        const SizedBox(height: 14),
        _Title('Frequently asked'),
      ],
    );
    final list = Column(
      children: [
        for (int i = 0; i < _faqs.length; i++)
          _FaqItem('Q-0${i + 1}', _faqs[i], initiallyOpen: i == 0),
      ],
    );
    return _Section(
      color: AppColors.bg,
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: title),
                const SizedBox(width: 48),
                Expanded(flex: 6, child: list),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 24), list],
            ),
    );
  }
}
