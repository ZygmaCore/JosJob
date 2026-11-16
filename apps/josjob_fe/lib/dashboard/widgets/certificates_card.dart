part of '../dashboard_page.dart';

// =========================================================================
// Aside card listing recent certificates. Falls back to the shared empty
// state when the learner has none yet.
// =========================================================================
class _CertificatesCard extends StatelessWidget {
  final List<_Certificate> certificates;
  const _CertificatesCard(this.certificates);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Certificates',
            actionLabel: certificates.isEmpty ? null : 'View all',
            onAction: () => _demoAction(context),
          ),
          const SizedBox(height: 6),
          if (certificates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: _EmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'No certificates yet',
                subtitle: 'Finish a course to earn your first one.',
              ),
            )
          else
            for (final c in certificates) _CertificateRow(c),
        ],
      ),
    );
  }
}
