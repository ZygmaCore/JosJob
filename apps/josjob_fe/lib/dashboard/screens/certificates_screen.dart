part of '../dashboard_page.dart';

// =========================================================================
// Certificates destination (learner Learn view): the certificates you hold,
// plus certificates matched to your profile.
// =========================================================================
class _CertificatesScreen extends StatelessWidget {
  final List<_Certificate> certificates;
  const _CertificatesScreen(this.certificates);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('My certificates'),
        const SizedBox(height: 16),
        _DashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      certificates.isEmpty
                          ? 'No certificates yet'
                          : '${certificates.length} earned',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.body,
                      ),
                    ),
                  ),
                  _PillButton(
                    label: 'Add certificate',
                    icon: Icons.add,
                    variant: _PillVariant.filled,
                    onPressed: () => _demoAction(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _InfoNote(
                'Adding your certificates helps us match you to suitable jobs.',
              ),
              const SizedBox(height: 8),
              if (certificates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _EmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Nothing here yet',
                    subtitle: 'Finish a course to earn your first certificate.',
                    actionLabel: 'Browse courses',
                    onAction: () => _explore(context),
                  ),
                )
              else
                for (final c in certificates) _CertificateRow(c),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const _SectionHeader('Target certificates'),
        const SizedBox(height: 6),
        Text(
          'Recommended from your profile and saved roles.',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _TargetCertGrid(_targetCertificates),
      ],
    );
  }
}

// Responsive grid of target-certificate cards: 2-up when wide, else stacked.
class _TargetCertGrid extends StatelessWidget {
  final List<_TargetCert> certs;
  const _TargetCertGrid(this.certs);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 2 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cert in certs)
              SizedBox(width: itemW, child: _TargetCertCard(cert)),
          ],
        );
      },
    );
  }
}
