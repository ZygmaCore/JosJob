part of '../dashboard_page.dart';

// =========================================================================
// Rendered for every non-Overview destination: a centered icon tile, the
// destination name, a "coming soon" note, and a subtle sample empty-state
// card so the screen never reads as blank.
// =========================================================================
class _PlaceholderPanel extends StatelessWidget {
  final _NavDest dest;
  final _DashView view;
  const _PlaceholderPanel(this.dest, {this.view = _DashView.learn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.tintBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(dest.icon, size: 34, color: AppColors.iconBlue),
              ),
              const SizedBox(height: 18),
              Text(
                dest.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This section is a demo — coming soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _DashCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here yet',
            subtitle:
                'When "${dest.label}" is live, your content will appear in this space.',
            actionLabel: view == _DashView.jobs
                ? 'Browse roles'
                : 'Explore courses',
            onAction: () {
              if (view == _DashView.jobs) {
                _browseJobs(context);
              } else {
                _explore(context);
              }
            },
          ),
        ),
      ],
    );
  }
}
