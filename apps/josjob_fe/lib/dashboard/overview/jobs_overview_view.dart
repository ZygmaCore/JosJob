import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../jobs/jobs_page.dart' show showJobListing;
import '../../services/jobs_api.dart';
import '../../services/jobs_overview_api.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';

typedef JobsOverviewAuthorize =
    Future<T> Function<T>(Future<T> Function(String) call);

class JobsOverviewView extends StatefulWidget {
  final JobsOverviewApi? api;
  final JobsOverviewAuthorize? authorize;
  final String? firstName;
  final VoidCallback? onBrowseJobs;
  final Future<void> Function(JobListing)? onOpenJob;
  final Future<void> Function()? onEditProfile;
  const JobsOverviewView({
    super.key,
    this.api,
    this.authorize,
    this.firstName,
    this.onBrowseJobs,
    this.onOpenJob,
    this.onEditProfile,
  });
  @override
  State<JobsOverviewView> createState() => _JobsOverviewViewState();
}

class _JobsOverviewViewState extends State<JobsOverviewView> {
  late final _api = widget.api ?? JobsOverviewApi();
  JobsOverviewData? _data;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    if (widget.api == null) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await (widget.authorize ?? Session.instance.runAuthed)(
        _api.fetch,
      );
      if (mounted && generation == _generation) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(JobListing job) async {
    if (widget.onOpenJob != null) {
      await widget.onOpenJob!(job);
    } else {
      await showJobListing(
        context,
        job,
        organizations: _data!.organizations,
        authorize: widget.authorize ?? Session.instance.runAuthed,
      );
    }
    if (mounted) {
      await _load();
    }
  }

  Future<void> _browse() async {
    if (widget.onBrowseJobs != null) {
      widget.onBrowseJobs!();
      return;
    }
    await Navigator.of(context).pushNamed('/jobs');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _profile() async {
    if (widget.onEditProfile != null) {
      await widget.onEditProfile!();
    } else {
      await Navigator.of(context).pushNamed('/onboarding');
    }
    if (mounted) {
      await _load();
    }
  }

  TextStyle _style(
    double size, {
    bool bold = false,
    Color color = AppColors.navy,
  }) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    color: color,
  );
  Widget _card(Widget child, {Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
  ButtonStyle get _button => FilledButton.styleFrom(
    textStyle: _style(13, bold: true),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  );
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('jobs-overview'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (widget.firstName ?? '').trim().isEmpty
                      ? 'Your job search'
                      : 'Hi ${widget.firstName!.trim()}!',
                  style: _style(26, bold: true),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current vacancies and saved profile details.',
                  style: _style(14, color: AppColors.body),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('refresh-jobs-overview'),
            tooltip: 'Refresh jobs overview',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: AppColors.brandBlue),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (_loading)
        _card(const Center(child: CircularProgressIndicator()))
      else if (_error != null)
        _card(
          Column(
            children: [
              Text(_error!, style: _style(14)),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('retry-jobs-overview'),
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        )
      else if (_data != null)
        ..._content(_data!),
    ],
  );
  List<Widget> _content(JobsOverviewData d) => [
    LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 940 ? 4 : 2;
        final stats = [
          (
            'available',
            'Available vacancies',
            d.availableJobs,
            Icons.work_outline,
          ),
          ('remote', 'Remote roles', d.remoteJobs, Icons.public),
          ('full-time', 'Full-time roles', d.fullTimeJobs, Icons.schedule),
          (
            'recent',
            'Published last 7 days',
            d.publishedLast7Days,
            Icons.update,
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final (id, label, value, icon) in stats)
              SizedBox(
                width: (c.maxWidth - 16 * (columns - 1)) / columns,
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.brandBlue, size: 23),
                      const SizedBox(height: 14),
                      Text(
                        '$value',
                        key: ValueKey('jobs-stat-$id'),
                        style: _style(28, bold: true),
                      ),
                      const SizedBox(height: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 36),
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _style(12, color: AppColors.body),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 30),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text('Latest vacancies', style: _style(20, bold: true)),
        TextButton(
          key: const ValueKey('browse-overview-jobs'),
          onPressed: _browse,
          style: TextButton.styleFrom(textStyle: _style(13, bold: true)),
          child: const Text('Browse all roles'),
        ),
      ],
    ),
    const SizedBox(height: 6),
    Text(
      'Recently published opportunities. Showing up to 6 roles.',
      style: _style(13, color: AppColors.body),
    ),
    const SizedBox(height: 16),
    if (d.jobs.isEmpty)
      _card(
        Column(
          key: const ValueKey('empty-overview-jobs'),
          children: [
            const Icon(
              Icons.work_outline,
              size: 38,
              color: AppColors.brandBlue,
            ),
            const SizedBox(height: 14),
            Text('No vacancies available yet', style: _style(17, bold: true)),
            const SizedBox(height: 8),
            Text(
              'Vacancies will appear here when they are available to your account.',
              textAlign: TextAlign.center,
              style: _style(13, color: AppColors.body),
            ),
          ],
        ),
      )
    else
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 640 ? 2 : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final job in d.jobs)
                SizedBox(
                  width: (c.maxWidth - 16 * (columns - 1)) / columns,
                  child: _job(job),
                ),
            ],
          );
        },
      ),
    const SizedBox(height: 28),
    _profileCard(d.profile),
    if (!d.matchingAvailable || !d.applicationsAvailable) ...[
      const SizedBox(height: 20),
      _card(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.upcoming_outlined, color: AppColors.brandBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('More job search tools', style: _style(16, bold: true)),
                  const SizedBox(height: 5),
                  Text(
                    !d.matchingAvailable && !d.applicationsAvailable
                        ? 'Personalized matches and application tracking are coming soon.'
                        : !d.matchingAvailable
                        ? 'Personalized matches are coming soon.'
                        : 'Application tracking is coming soon.',
                    style: _style(13, color: AppColors.body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ];
  Widget _job(JobListing job) => _card(
    key: ValueKey('overview-job-${job.id}'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tintBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                job.company.trim().isEmpty
                    ? '?'
                    : job.company.trim().characters.first.toUpperCase(),
                style: _style(18, bold: true, color: AppColors.brandBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _style(16, bold: true),
                  ),
                  const SizedBox(height: 4),
                  Text(job.company, style: _style(13, color: AppColors.body)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${job.location} · ${_type(job.employmentType)} · ${_mode(job.workMode)}',
          style: _style(12, color: AppColors.body),
        ),
        const SizedBox(height: 10),
        Text(job.salaryLabel, style: _style(13, bold: true)),
        if (job.postedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Published ${job.postedAt!.toLocal().toIso8601String().split('T').first}',
              style: _style(11, color: AppColors.body),
            ),
          ),
        if (job.synthetic)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Synthetic listing',
              style: _style(12, bold: true, color: AppColors.brandBlue),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: ValueKey('open-overview-job-${job.id}'),
          style: _button,
          onPressed: () => _open(job),
          child: const Text('View role'),
        ),
      ],
    ),
  );
  String _type(String value) =>
      const {
        'full-time': 'Full-time',
        'part-time': 'Part-time',
        'internship': 'Internship',
        'contract': 'Contract',
        'freelance': 'Freelance',
      }[value] ??
      value;
  String _mode(String value) =>
      const {
        'remote': 'Remote',
        'hybrid': 'Hybrid',
        'onsite': 'Onsite',
      }[value] ??
      value;
  Widget _profileCard(JobsProfileSummary p) => _card(
    key: const ValueKey('jobs-profile-summary'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your saved profile', style: _style(19, bold: true)),
        const SizedBox(height: 8),
        Text(
          'Saved onboarding progress: ${p.onboardingProgress}%',
          style: _style(13, color: AppColors.body),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: p.onboardingProgress.clamp(0, 100) / 100,
            minHeight: 7,
            backgroundColor: AppColors.border,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            Text(
              '${p.skillCount} ${p.skillCount == 1 ? 'skill' : 'skills'} saved',
              style: _style(13, bold: true),
            ),
            Text(
              '${p.experienceCount} work history ${p.experienceCount == 1 ? 'record' : 'records'}',
              style: _style(13),
            ),
            Text(
              '${p.educationCount} education ${p.educationCount == 1 ? 'record' : 'records'}',
              style: _style(13),
            ),
            Text(
              '${p.certificatesSaved} certificate ${p.certificatesSaved == 1 ? 'record' : 'records'}',
              style: _style(13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (p.skills.isEmpty)
          Text(
            'Add skills during onboarding to keep your profile up to date.',
            style: _style(13, color: AppColors.body),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in p.skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(skill, style: _style(12)),
                ),
            ],
          ),
        if (p.skillCount > p.skills.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing the first ${p.skills.length} saved skills.',
              style: _style(11, color: AppColors.body),
            ),
          ),
        const SizedBox(height: 18),
        OutlinedButton(
          key: const ValueKey('update-overview-profile'),
          onPressed: _profile,
          style: OutlinedButton.styleFrom(
            textStyle: _style(13, bold: true),
            side: const BorderSide(color: AppColors.border),
          ),
          child: const Text('Update onboarding'),
        ),
      ],
    ),
  );
}
