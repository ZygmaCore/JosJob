part of '../jobs_page.dart';

typedef JobAuthorizer =
    Future<T> Function<T>(Future<T> Function(String token) call);

/// Shared by the standalone page and dashboard.
class JobsView extends StatefulWidget {
  final JobsApi? api;
  final JobAuthorizer? authorize;
  final bool embedded;
  final String initialQuery;
  const JobsView({
    super.key,
    this.api,
    this.authorize,
    this.initialQuery = '',
    this.embedded = false,
  });
  @override
  State<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<JobsView> {
  late final JobsApi _api = widget.api ?? JobsApi();
  JobAuthorizer get _authorize => widget.authorize ?? _authorizeJobs;
  final _query = TextEditingController();
  final _location = TextEditingController();
  final _industry = TextEditingController();
  final _salary = TextEditingController();
  Timer? _debounce;
  JobsPageResult? _result;
  String? _error, _savedCvId;
  List<String> _savedCvCategories = const [];
  bool _cvStateKnown = false, _cvLookupFailed = false;
  String _type = '', _mode = '', _currency = '', _sort = 'newest';
  bool _manage = false, _loading = true, _showFilters = false;
  int _page = 1, _request = 0;

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
    if (widget.authorize != null || Session.instance.isSignedIn) {
      _sort = 'relevance';
    }
    _load();
    _restoreLocation();
  }

  Future<void> _restoreLocation() async {
    try {
      final location = await const UiPreferences().preferredJobLocation(
        Session.instance.user?.id ?? 'guest',
      );
      if (mounted && _location.text.isEmpty && location.isNotEmpty) {
        _location.text = location;
        _load();
      }
    } catch (_) {
      /* Browsing remains available without local storage. */
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (_cvLookupFailed) {
        _cvStateKnown = false;
        _cvLookupFailed = false;
      }
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
        if (filters['scope'] == 'browse' && filters['sort'] == 'relevance') {
          if (result.relevanceStatus == 'ready' && result.cvId != null) {
            _savedCvId = result.cvId;
            _savedCvCategories = result.cvCategories;
            _cvLookupFailed = false;
          } else if (result.relevanceStatus == 'cv_required') {
            _savedCvId = null;
            _savedCvCategories = const [];
            _cvLookupFailed = false;
          } else if (!_cvStateKnown) {
            _cvLookupFailed = true;
          }
          _cvStateKnown = true;
        }
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        if (!_cvStateKnown) {
          _cvStateKnown = true;
          _cvLookupFailed = true;
        }
      });
    }
  }

  void _filter({bool debounce = false}) {
    unawaited(
      const UiPreferences()
          .saveJobLocation(Session.instance.user?.id ?? 'guest', _location.text)
          .catchError((_) {}),
    );
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
      _sort = widget.authorize != null || Session.instance.isSignedIn
          ? 'relevance'
          : 'newest';
    });
    _filter();
  }

  Future<void> _open(JobListing job) async {
    await showJobListing(
      context,
      job,
      api: _api,
      authorize: _authorize,
      organizations: _result?.organizations ?? const [],
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
      setState(() {
        _manage = true;
        _sort = 'newest';
      });
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
        constraints: const BoxConstraints(maxWidth: Bp.maxContent),
        child: Padding(
          padding: EdgeInsets.all(
            widget.embedded
                ? 0
                : (MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 22 : 36,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.tintBlue, AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EXPLORE YOUR NEXT OPPORTUNITY',
                      style: TextStyle(
                        color: AppColors.brandBlue,
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
                        color: AppColors.navy,
                        fontSize: MediaQuery.sizeOf(context).width < 600
                            ? 26
                            : 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _manage
                          ? 'Create and manage opportunities for your organization.'
                          : 'Explore opportunities from hiring teams. Find a role worth growing into.',
                      style: GoogleFonts.poppins(
                        color: AppColors.body,
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
                              setState(() {
                                _manage = false;
                                _sort = 'relevance';
                              });
                              _filter();
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('manage-jobs'),
                            label: const Text('Manage listings'),
                            selected: _manage,
                            onSelected: (_) {
                              setState(() {
                                _manage = true;
                                _sort = 'newest';
                              });
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
              if (!_manage) ...[
                CvJobRankings(
                  key: ValueKey(
                    'cv-state-${Session.instance.user?.id ?? 'guest'}',
                  ),
                  authorize: widget.authorize,
                  savedCvId: _savedCvId,
                  savedCategories: _savedCvCategories,
                  checkingSavedCv: _loading && !_cvStateKnown,
                  savedCvUnavailable: _cvLookupFailed,
                  onRetrySavedCv: _error == null ? _load : null,
                  onProfileReady: (result) {
                    setState(() {
                      _sort = 'relevance';
                      _savedCvId = result['cv_id'] as String?;
                      _savedCvCategories = List<String>.from(
                        (result['profile'] as Map?)?['categories'] as List? ??
                            [],
                      );
                      _cvStateKnown = true;
                      _cvLookupFailed = false;
                    });
                    _filter();
                  },
                ),
                const SizedBox(height: 24),
              ],
              _filterPanel(),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    _manage
                        ? 'Organization listings'
                        : _loading
                        ? 'Finding opportunities...'
                        : _error != null
                        ? 'Opportunities'
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
                      _select(
                        'Sort by',
                        _sort,
                        {
                          if (!_manage &&
                              (widget.authorize != null ||
                                  Session.instance.isSignedIn))
                            'relevance': 'Most relevant to my CV',
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
              if (!_manage &&
                  _sort == 'relevance' &&
                  !_loading &&
                  _error == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _result?.relevanceStatus == 'cv_required'
                        ? 'Upload and save your CV above to sort by relevance. Showing newest jobs for now.'
                        : 'Relevant categories and skills first. Less relevant jobs remain below.',
                    key: const ValueKey('job-relevance-status'),
                  ),
                ),
              if (_activeFilters.isNotEmpty) ...[
                Wrap(spacing: 8, runSpacing: 8, children: _activeFilters),
                const SizedBox(height: 16),
              ],
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
                    final width = constraints.maxWidth >= 760
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

  Widget _filterPanel() {
    final type = _select('Employment type', _type, const {
      '': 'All types',
      'full-time': 'Full-time',
      'part-time': 'Part-time',
      'internship': 'Internship',
      'contract': 'Contract',
      'freelance': 'Freelance',
    }, (v) => _type = v);
    final mode = _select('Work mode', _mode, const {
      '': 'All modes',
      'remote': 'Remote',
      'hybrid': 'Hybrid',
      'onsite': 'Onsite',
    }, (v) => _mode = v);
    final search = _SearchField(
      controller: _query,
      onChanged: (_) => _filter(debounce: true),
    );
    return Container(
      key: const ValueKey('jobs-filter-panel'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 16),
                    Expanded(child: type),
                    const SizedBox(width: 16),
                    Expanded(child: mode),
                  ],
                )
              else ...[
                search,
                const SizedBox(height: 16),
                _filterGrid([type, mode], maxColumns: 2),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const ValueKey('jobs-more-filters'),
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                    icon: Icon(
                      _showFilters ? Icons.expand_less : Icons.tune_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showFilters ? 'Fewer filters' : 'More filters',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Clear filters',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_showFilters) ...[
                const Divider(height: 24, color: AppColors.border),
                _filterGrid([
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
                  _textFilter('Minimum monthly salary', _salary, number: true),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _filterGrid(List<Widget> fields, {int maxColumns = 4}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 850
              ? maxColumns
              : constraints.maxWidth >= 340
              ? 2
              : 1;
          final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final field in fields) SizedBox(width: width, child: field),
            ],
          );
        },
      );

  List<Widget> get _activeFilters {
    Widget chip(String label, VoidCallback clear) => InputChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.navy),
      ),
      backgroundColor: AppColors.tintBlue,
      side: BorderSide.none,
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () {
        setState(clear);
        _filter();
      },
    );
    return [
      if (_query.text.trim().isNotEmpty)
        chip('Search: ${_query.text.trim()}', _query.clear),
      if (_type.isNotEmpty) chip(_type, () => _type = ''),
      if (_mode.isNotEmpty) chip(_mode, () => _mode = ''),
      if (_location.text.trim().isNotEmpty)
        chip('Location: ${_location.text.trim()}', _location.clear),
      if (_industry.text.trim().isNotEmpty)
        chip('Industry: ${_industry.text.trim()}', _industry.clear),
      if (_salary.text.isNotEmpty)
        chip('From $_currency ${_salary.text}/month', _salary.clear),
      if (_currency.isNotEmpty)
        chip(_currency, () {
          _currency = '';
          _salary.clear();
          _sort = 'newest';
        }),
    ];
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.body),
      ),
      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navy),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.body),
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
    child: AppStateView(
      icon: icon,
      title: action == 'Try again' ? 'Jobs unavailable' : 'No matching jobs',
      message: text,
      actionLabel: action,
      onAction: onTap,
      error: action == 'Try again',
    ),
  );
}
