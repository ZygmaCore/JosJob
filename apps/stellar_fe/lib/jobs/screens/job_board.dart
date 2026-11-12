part of '../jobs_page.dart';

typedef JobAuthorizer =
    Future<T> Function<T>(Future<T> Function(String token) call);

/// Shared by the standalone page and dashboard.
class JobsView extends StatefulWidget {
  final JobsApi? api;
  final JobAuthorizer? authorize;
  const JobsView({super.key, this.api, this.authorize});
  @override
  State<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<JobsView> {
  late final JobsApi _api = widget.api ?? JobsApi();
  JobAuthorizer get _authorize =>
      widget.authorize ?? Session.instance.runAuthed;
  final _query = TextEditingController();
  final _location = TextEditingController();
  final _industry = TextEditingController();
  final _salary = TextEditingController();
  Timer? _debounce;
  JobsPageResult? _result;
  String? _error;
  String _type = '', _mode = '', _currency = '', _sort = 'newest';
  bool _manage = false, _loading = true;
  int _page = 1, _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final filters = <String, String>{
      'q': _query.text.trim(),
      'location': _location.text.trim(),
      'industry': _industry.text.trim(),
      'employment_type': _type,
      'work_mode': _mode,
      'sort': _sort,
      'scope': _manage ? 'manage' : 'browse',
      if (_currency.isNotEmpty) 'currency': _currency,
      if (_salary.text.trim().isNotEmpty) 'salary_min': _salary.text.trim(),
    };
    try {
      final result = await _authorize(
        (token) => _api.list(token, filters: filters, page: _page),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter({bool debounce = false}) {
    _debounce?.cancel();
    ++_request;
    _page = 1;
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), _load);
    } else {
      _load();
    }
  }

  void _reset() {
    _query.clear();
    _location.clear();
    _industry.clear();
    _salary.clear();
    setState(() {
      _type = '';
      _mode = '';
      _currency = '';
      _sort = 'newest';
    });
    _filter();
  }

  Future<void> _open(JobListing job) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JobDetailPage(
          jobId: job.id,
          api: _api,
          authorize: _authorize,
          organizations: _result?.organizations ?? const [],
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JobEditor(
          api: _api,
          authorize: _authorize,
          organizations: _result!.organizations
              .where((o) => o.canPost)
              .toList(),
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _manage = true);
      _filter();
    }
  }

  @override
  void dispose() {
    ++_request;
    _debounce?.cancel();
    _query.dispose();
    _location.dispose();
    _industry.dispose();
    _salary.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgs = _result?.organizations ?? const <JobOrganization>[];
    final canPost = orgs.any((o) => o.canPost);
    final canManage = orgs.any((o) => o.canPost || o.canManage);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.brandBlue],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JOSJOB / OPPORTUNITIES',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _manage
                          ? 'Build your next great team.'
                          : 'Your next chapter starts here.',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _manage
                          ? 'Create and manage your organization’s opportunities.'
                          : 'Explore opportunities from your organizations. Find a role worth growing into.',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Browse jobs'),
                            selected: !_manage,
                            onSelected: (_) {
                              setState(() => _manage = false);
                              _filter();
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('manage-jobs'),
                            label: const Text('Manage listings'),
                            selected: _manage,
                            onSelected: (_) {
                              setState(() => _manage = true);
                              _filter();
                            },
                          ),
                          if (canPost)
                            FilledButton.icon(
                              key: const ValueKey('post-job'),
                              onPressed: _create,
                              icon: const Icon(Icons.add),
                              label: const Text('Post a job'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SearchField(
                controller: _query,
                onChanged: (_) => _filter(debounce: true),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _select('Employment type', _type, const {
                    '': 'All types',
                    'full-time': 'Full-time',
                    'part-time': 'Part-time',
                    'internship': 'Internship',
                    'contract': 'Contract',
                    'freelance': 'Freelance',
                  }, (v) => _type = v),
                  _select('Work mode', _mode, const {
                    '': 'All modes',
                    'remote': 'Remote',
                    'hybrid': 'Hybrid',
                    'onsite': 'Onsite',
                  }, (v) => _mode = v),
                ],
              ),
              ExpansionTile(
                title: const Text('More filters'),
                tilePadding: EdgeInsets.zero,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _textFilter('Location', _location),
                      _textFilter('Industry', _industry),
                      _select(
                        'Currency',
                        _currency,
                        const {
                          '': 'All currencies',
                          'IDR': 'IDR',
                          'USD': 'USD',
                          'AUD': 'AUD',
                          'EUR': 'EUR',
                          'GBP': 'GBP',
                        },
                        (v) {
                          _currency = v;
                          if (v.isEmpty) {
                            _salary.clear();
                            _sort = 'newest';
                          }
                        },
                      ),
                      _textFilter(
                        'Minimum monthly salary',
                        _salary,
                        number: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    _manage
                        ? 'Your organization’s listings'
                        : '${_result?.total ?? 0} opportunities',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Clear filters'),
                      ),
                      _select(
                        'Sort by',
                        _sort,
                        const {
                          'newest': 'Newest first',
                          'salary': 'Highest salary',
                        },
                        (v) {
                          _sort = v;
                          if (v == 'salary' && _currency.isEmpty) {
                            _currency = 'IDR';
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('jobs-loading'),
                    ),
                  ),
                )
              else if (_error != null)
                _message(
                  Icons.cloud_off_outlined,
                  _error!,
                  'Try again',
                  _load,
                  key: const ValueKey('jobs-error'),
                )
              else if (_result?.jobs.isEmpty ?? true)
                _message(
                  Icons.work_outline,
                  _manage
                      ? 'No listings yet. Create your first opportunity.'
                      : 'No jobs found. Try a broader role, location or industry.',
                  'Clear filters',
                  _reset,
                  key: const ValueKey('jobs-empty'),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 800
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final job in _result!.jobs)
                          SizedBox(
                            width: width,
                            child: _JobCard(
                              key: ValueKey('job-${job.id}'),
                              job: job,
                              onTap: () => _open(job),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const ValueKey('jobs-previous'),
                      tooltip: 'Previous page',
                      onPressed: _page > 1
                          ? () {
                              --_page;
                              _load();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Page ${_result!.page} of ${_result!.totalPages}'),
                    IconButton(
                      key: const ValueKey('jobs-next'),
                      tooltip: 'Next page',
                      onPressed: _page < _result!.totalPages
                          ? () {
                              ++_page;
                              _load();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) update,
  ) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surface,
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => update(v));
        _filter();
      },
    ),
  );

  Widget _textFilter(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      key: ValueKey('jobs-filter-$label'),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.surface,
      ),
      onChanged: (_) {
        if (number && controller.text.isNotEmpty && _currency.isEmpty) {
          setState(() => _currency = 'IDR');
        }
        _filter(debounce: true);
      },
    ),
  );

  Widget _message(
    IconData icon,
    String text,
    String action,
    VoidCallback onTap, {
    Key? key,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.iconBlue),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}
