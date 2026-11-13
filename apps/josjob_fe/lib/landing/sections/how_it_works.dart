part of '../landing_page_ascent.dart';

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({super.key});

  @override
  Widget build(BuildContext context) => _Section(
    color: AppColors.paper,
    child: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 760;
        final steps = const [
          (
            '01',
            'Explore roles',
            'Search opportunities by role, skills or location.',
          ),
          (
            '02',
            'Bring your CV',
            'Add your CV with consent to prepare your job-seeker profile.',
          ),
          (
            '03',
            'Close the gap',
            'Use learning on JosJob to build skills, then apply.',
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('From search to next step'),
            const SizedBox(height: 12),
            _Title('A more connected job search'),
            const SizedBox(height: 28),
            compact
                ? Column(
                    children: [
                      for (final step in steps)
                        _JourneyStep(step: step, compact: true),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == steps.length - 1 ? 0 : 28,
                            ),
                            child: _JourneyStep(step: steps[i], compact: false),
                          ),
                        ),
                    ],
                  ),
            const SizedBox(height: 12),
            Text(
              'CV analysis, personalized ranking and applications are planned features. This preview shows the intended journey.',
              style: TextStyle(
                fontFamily: 'General Sans',
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _JourneyStep extends StatelessWidget {
  final (String, String, String) step;
  final bool compact;
  const _JourneyStep({required this.step, required this.compact});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 22 : 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.$1,
          style: const TextStyle(
            fontFamily: 'Geist Mono',
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.$2,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  color: AppColors.landingInk,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.$3,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
