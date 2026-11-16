part of '../dashboard_page.dart';

// =========================================================================
// Applications destination (candidate Jobs view): a pipeline summary of the
// candidate's applications by stage, plus the full list of live applications.
// =========================================================================
class _JobApplicationsScreen extends StatelessWidget {
  const _JobApplicationsScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Applications',
          actionLabel: 'Find roles',
          onAction: () => _browseJobs(context),
        ),
        const SizedBox(height: 6),
        Text(
          '${_allApplications.length} active applications',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        const _JobAppSummary(),
        const SizedBox(height: 24),
        _DashCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < _allApplications.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _JobAppRow(_allApplications[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Responsive grid of per-stage counts: 4-up when wide, else 2-up.
class _JobAppSummary extends StatelessWidget {
  const _JobAppSummary();

  int _count(_AppStage stage) =>
      _allApplications.where((a) => a.stage == stage).length;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    final tiles = [
      _JobAppStat(
        count: _count(_AppStage.applied),
        label: 'Applied',
        tint: AppColors.tintBlue,
        fg: AppColors.brandBlue,
      ),
      _JobAppStat(
        count: _count(_AppStage.screening),
        label: 'Screening',
        tint: AppColors.tintOrange,
        fg: AppColors.iconOrange,
      ),
      _JobAppStat(
        count: _count(_AppStage.interview),
        label: 'Interview',
        tint: AppColors.tintGreen,
        fg: AppColors.iconGreen,
      ),
      _JobAppStat(
        count: _count(_AppStage.offer),
        label: 'Offer',
        tint: AppColors.tintGreen,
        fg: AppColors.iconGreen,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: itemW, child: tile),
          ],
        );
      },
    );
  }
}

// A single stage tile: the count over its stage label.
class _JobAppStat extends StatelessWidget {
  final int count;
  final String label;
  final Color tint;
  final Color fg;
  const _JobAppStat({
    required this.count,
    required this.label,
    required this.tint,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: _tabular(
              GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

// A single application row: logo tile, role/company/location/when, stage chip.
class _JobAppRow extends StatelessWidget {
  final _Application app;
  const _JobAppRow(this.app);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _thumbGradient(app.seed),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _initials(app.company),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                  '${app.company} · ${app.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  app.when,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
