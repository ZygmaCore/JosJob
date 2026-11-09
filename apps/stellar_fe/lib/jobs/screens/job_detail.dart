part of '../jobs_page.dart';

// =========================================================================
// Role detail: a header card (logo, title, company, match, meta) followed by
// the summary and two bullet lists, then a demo apply/save action bar.
// =========================================================================
class _JobDetailPage extends StatelessWidget {
  final _Job job;
  const _JobDetailPage(this.job);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0.5,
        foregroundColor: AppColors.ink,
        title: Text(
          'Role details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _HeaderCard(job),
                const SizedBox(height: 24),
                _DetailSection(
                  'About the role',
                  child: Text(
                    job.summary,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      height: 1.6,
                      color: AppColors.body,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _DetailSection(
                  'What you\'ll do',
                  child: _BulletList(job.highlights),
                ),
                const SizedBox(height: 24),
                _DetailSection(
                  'What you\'ll need',
                  child: _BulletList(job.requirements),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            _demo(context, 'Application sent (demo).'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Apply now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _demo(context, 'Saved (demo).'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Header card with the role identity + meta.
class _HeaderCard extends StatelessWidget {
  final _Job job;
  const _HeaderCard(this.job);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [_cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _logoGradient(job.seed),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _initials(job.company),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MatchBadge(job.matchPct),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _meta(Icons.place_outlined, job.location),
              _meta(Icons.schedule_outlined, job.type),
              _meta(Icons.payments_outlined, job.salary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.iconBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

// A titled content block.
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailSection(this.title, {required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// A tick-marked bullet list.
class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.iconGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
