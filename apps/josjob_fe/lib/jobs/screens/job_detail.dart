part of '../jobs_page.dart';

class _JobDetailPage extends StatefulWidget {
  final String jobId;
  final JobsApi api;
  final JobAuthorizer authorize;
  final List<JobOrganization> organizations;
  const _JobDetailPage({
    required this.jobId,
    required this.api,
    required this.authorize,
    required this.organizations,
  });
  @override
  State<_JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<_JobDetailPage> {
  late Future<JobListing> _job = _fetch();
  bool _deleting = false;
  Future<JobListing> _fetch() =>
      widget.authorize((token) => widget.api.get(token, widget.jobId));

  Future<void> _edit(JobListing job) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JobEditor(
          api: widget.api,
          authorize: widget.authorize,
          organizations: widget.organizations,
          job: job,
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _job = _fetch());
  }

  Future<void> _delete(JobListing job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text('“${job.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.authorize((token) => widget.api.delete(token, job.id));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _demo(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('Role details')),
    body: FutureBuilder<JobListing>(
      future: _job,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error.toString(),
                    key: const ValueKey('job-detail-error'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _job = _fetch()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final job = snapshot.data!;
        return SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    key: const ValueKey('job-detail'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(job),
                      const SizedBox(height: 24),
                      _DetailSection(
                        'About the role',
                        child: Text(
                          job.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            height: 1.7,
                            color: AppColors.body,
                          ),
                        ),
                      ),
                      if (job.highlights.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DetailSection(
                          'What you’ll do',
                          child: _BulletList(job.highlights),
                        ),
                      ],
                      if (job.requirements.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DetailSection(
                          'Skills you’ll need',
                          child: _BulletList(job.requirements),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (job.canManage)
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('edit-job'),
                              onPressed: _deleting ? null : () => _edit(job),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit listing'),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('delete-job'),
                              onPressed: _deleting ? null : () => _delete(job),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(
                                _deleting ? 'Deleting…' : 'Delete listing',
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'CV matching and in-platform applications are coming next. Browse the requirements to prepare for this opportunity.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// Header card with the role identity + meta.
class _HeaderCard extends StatelessWidget {
  final JobListing job;
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
                  gradient: _logoGradient(job.company.length),
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
              if (job.synthetic) const _JobBadge('Synthetic demo'),
              if (job.status != 'active') _JobBadge(job.status),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _meta(Icons.place_outlined, job.location),
              _meta(Icons.schedule_outlined, job.employmentType),
              _meta(Icons.business_center_outlined, job.workMode),
              _meta(Icons.payments_outlined, job.salaryLabel),
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
