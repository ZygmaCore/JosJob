part of '../quiz_page.dart';

// =========================================================================
// App-style top bar for the quiz hub: a back affordance + page title, with the
// brand mark on the right (desktop). Reached from the dashboard, so this is an
// in-app bar rather than the landing marketing nav.
// =========================================================================
class _QuizTopNav extends StatelessWidget {
  final VoidCallback onBack;
  const _QuizTopNav({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.10),
      child: _Bounded(
        child: SizedBox(
          height: Bp.navHeight,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Quizzes & assessments',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: mobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
              if (!mobile) ...[const SizedBox(width: 12), const _Logo()],
            ],
          ),
        ),
      ),
    );
  }
}
