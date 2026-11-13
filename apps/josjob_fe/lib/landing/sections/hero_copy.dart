part of '../landing_page_ascent.dart';

class _HeroCopy extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onHowItWorks;
  const _HeroCopy({required this.onCta, required this.onHowItWorks});

  @override
  Widget build(BuildContext context) {
    final wide = _zig(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          child: Text(
            'A clearer first step after graduation',
            style: TextStyle(
              fontFamily: 'General Sans',
              color: AppColors.landingInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            'Learn the skills for\nyour next role.',
            style: _display(
              context,
              color: AppColors.landingInk,
            ).copyWith(height: 1.04, letterSpacing: -1.8),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
<<<<<<< Updated upstream:apps/josjob_fe/lib/landing/sections/hero_copy.dart
            'JosJob is one platform for your whole career — build '
            'job-ready skills through flexible online learning, then get '
            'matched with the employers who are hiring. Study at your own '
            'pace, earn the certifications that matter, and get hired.',
=======
            'JosJob connects job opportunities with learning, so you can build '
            'job-ready skills and take a clearer next step toward employment.',
>>>>>>> Stashed changes:apps/stellar_fe/lib/landing/sections/hero_copy.dart
            style: _lead(context),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.cotton,
            border: Border.all(color: AppColors.rule),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.landingInk.withValues(alpha: .09),
                blurRadius: 12,
                offset: const Offset(6, 7),
              ),
            ],
          ),
          child: wide
              ? Row(
                  children: [
                    const Expanded(child: _RoleSearchField()),
                    _PillButton(
                      'Get started',
                      trailing: Icons.arrow_forward,
                      onPressed: onCta,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _RoleSearchField(),
                    const SizedBox(height: 6),
                    _PillButton(
                      'Get started',
                      trailing: Icons.arrow_forward,
                      onPressed: onCta,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Create a profile to explore opportunities and learning in one place.',
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Explore jobs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.landingInk,
                side: const BorderSide(color: AppColors.rule),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onHowItWorks,
              icon: const Icon(Icons.arrow_downward, size: 17),
              label: const Text('See how it works'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.landingInk,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleSearchField extends StatelessWidget {
  const _RoleSearchField();

  @override
  Widget build(BuildContext context) => TextField(
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => Navigator.of(context).pushNamed('/register'),
    decoration: InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: true,
      fillColor: AppColors.cotton,
      hintText: 'Job title, skill or company',
      prefixIcon: const Icon(Icons.search, color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      hintStyle: TextStyle(
        fontFamily: 'General Sans',
        fontSize: 14,
        color: AppColors.muted,
      ),
    ),
  );
}
