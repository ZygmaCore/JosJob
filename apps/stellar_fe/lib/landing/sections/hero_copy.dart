part of '../landing_page_ascent.dart';

class _HeroCopy extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onHowItWorks;
  const _HeroCopy({required this.onCta, required this.onHowItWorks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Learn the skills for education and successful employment.',
            style: _display(context, color: AppColors.navy),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Atveti Stellar is one platform for your whole career — build '
            'job-ready skills through flexible online learning, then get '
            'matched with the employers who are hiring. Study at your own '
            'pace, earn the certifications that matter, and get hired.',
            style: _lead(context),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            _PillButton(
              'Get started',
              trailing: Icons.arrow_forward,
              onPressed: onCta,
            ),
            _PillButton(
              'See how it works',
              kind: _BtnKind.ghost,
              onPressed: onHowItWorks,
            ),
          ],
        ),
      ],
    );
  }
}
