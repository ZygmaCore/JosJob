part of '../landing_page_ascent.dart';

class _MomentsSection extends StatelessWidget {
  const _MomentsSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppColors.bg,
      child: Column(
        children: [
          const _Eyebrow('In the field'),
          const SizedBox(height: 14),
          _Title('Training in action', center: true),
          const SizedBox(height: 12),
          Text(
            'Live coaching and workshops, delivered where you work.',
            textAlign: TextAlign.center,
            style: _lead(context),
          ),
          const SizedBox(height: 36),
          _CardGrid(
            desktop: 3,
            tablet: 2,
            mobile: 1,
            children: [for (final m in _moments) _PhotoTile(caption: m)],
          ),
        ],
      ),
    );
  }
}
