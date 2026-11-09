part of '../dashboard_page.dart';

// =========================================================================
// The candidate's live applications, as a single card of divided rows, each
// showing the role/company and a pipeline-stage chip.
// =========================================================================
class _ApplicationsCard extends StatelessWidget {
  final List<_Application> apps;
  const _ApplicationsCard(this.apps);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < apps.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _ApplicationRow(apps[i]),
          ],
        ],
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  final _Application app;
  const _ApplicationRow(this.app);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${app.company} · ${app.when}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StageChip(app.stage),
        ],
      ),
    );
  }
}

// Pipeline-stage pill; colour is always paired with a label (never hue alone).
class _StageChip extends StatelessWidget {
  final _AppStage stage;
  const _StageChip(this.stage);

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (stage) {
      _AppStage.applied => ('Applied', AppColors.tintBlue, AppColors.brandBlue),
      _AppStage.screening => (
        'Screening',
        AppColors.tintOrange,
        AppColors.iconOrange,
      ),
      _AppStage.interview => (
        'Interview',
        AppColors.tintGreen,
        AppColors.iconGreen,
      ),
      _AppStage.offer => ('Offer', AppColors.tintGreen, AppColors.iconGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
