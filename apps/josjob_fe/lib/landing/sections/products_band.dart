part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Products band — the two ways to grow with JosJob, presented up
// front (right below the hero) so both products are clear before the learning
// journey spine. This is where the Job Placement narrative is folded in.
// -------------------------------------------------------------------------
class _ProductsBand extends StatelessWidget {
  const _ProductsBand();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppColors.paper,
      child: Column(
        children: [
          const _Eyebrow('SEARCH · SKILLS · LEARNING'),
          const SizedBox(height: 14),
          _Title('A job search connected to learning', center: true),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              'From your first module to your first day on the job — Atveti '
              'JosJob takes you the whole way, in one place.',
              textAlign: TextAlign.center,
              style: _lead(context),
            ),
          ),
          const SizedBox(height: 32),
          _CardGrid(
            desktop: 2,
            tablet: 2,
            mobile: 1,
            children: [for (final it in _products) _ProgramCard(it)],
          ),
        ],
      ),
    );
  }
}
