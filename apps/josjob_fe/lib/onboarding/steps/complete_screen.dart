part of '../onboarding_page.dart';

// =========================================================================
// Completion
// =========================================================================
class _CompleteScreen extends StatelessWidget {
  final String? firstName;
  final VoidCallback onContinue;
  const _CompleteScreen({
    super.key,
    required this.firstName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final name = (firstName ?? '').trim();
    final headline = name.isEmpty
        ? "You're all set!"
        : "You're all set, $name!";
    final blurb =
        'Your learning path is ready. Jump into your dashboard to '
        'start your first module.';

    return _ContentShell(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.tintGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.iconGreen,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: _compact(context) ? 26 : 32,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              blurb,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.55,
                color: AppColors.body,
              ),
            ),
            const SizedBox(height: 30),
            _PillButton(
              label: 'Go to dashboard',
              onPressed: onContinue,
              busy: false,
            ),
          ],
        ),
      ),
    );
  }
}
