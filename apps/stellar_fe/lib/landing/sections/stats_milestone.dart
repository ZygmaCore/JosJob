part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Milestone content
// -------------------------------------------------------------------------
class _StatsMilestone extends StatelessWidget {
  const _StatsMilestone();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Eyebrow('MILESTONE 01 · WHY ATVETI STELLAR'),
        const SizedBox(height: 14),
        _Title('Training built around your workplace', center: true),
        const SizedBox(height: 32),
        _CardGrid(
          desktop: 4,
          tablet: 2,
          mobile: 2,
          children: [
            for (final (value, unit, desc) in _stats)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'General Sans',
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontFamily: 'General Sans',
                              fontSize: 13,
                              color: AppColors.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: _lead(
                        context,
                      ).copyWith(fontSize: 13.5, height: 1.45),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
