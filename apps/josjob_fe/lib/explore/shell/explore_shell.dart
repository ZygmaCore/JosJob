part of '../explore_page.dart';

// =========================================================================
// Stateful orchestrator — fetches the live course catalog once, owns the
// filter/sort/paging state, derives the visible list each build, and composes
// the page. Delegated to by the public ExploreCoursePage.
// =========================================================================
class _ExploreShell extends StatefulWidget {
  // When embedded (inside the dashboard's "Courses" tab) the page drops its own
  // chrome — top nav, footer, top spacer and Scaffold/scroll — and lets the
  // host provide them.
  final bool embedded;
  const _ExploreShell({this.embedded = false});

  @override
  State<_ExploreShell> createState() => _ExploreShellState();
}

class _ExploreShellState extends State<_ExploreShell> {
  static const int _pageSize = 6;

  final _gridKey = GlobalKey();
  final _searchCtrl = TextEditingController();

  final CoursesApi _api = CoursesApi();

  // ---- Remote state: the fetched catalog + load status --------------------
  List<_Course> _all = const [];
  bool _loading = true;
  String? _error; // null when the last load succeeded
  bool _didInit = false;

  // ---- Local view state: filters / sort / paging --------------------------
  String _query = '';
  String? _industry; // industry NAME, null = all fields
  _SortBy _sort = _SortBy.az;

  final Set<String> _saved = {}; // saved course ids (local only)
  int _visible = _pageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _api.close();
    super.dispose();
  }

  // ---- Fetch the catalog (Bearer + refresh-on-401 via Session) ------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Session.instance.runAuthed(_api.listCourses);
      if (!mounted) return;
      setState(() {
        _all = list.map(_Course.fromApi).toList();
        _loading = false;
      });
    } on CourseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  // ---- Derived list: ONE filter+sort pass, recomputed each build ----------
  List<_Course> get _results {
    final q = _query.trim().toLowerCase();
    final list = _all.where((c) {
      if (_industry != null && !c.industries.contains(_industry)) return false;
      if (q.isNotEmpty) {
        final hay =
            '${c.title} ${c.summary} ${c.industries.join(' ')} '
                    '${c.section ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortBy.az:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SortBy.za:
        list.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case _SortBy.mostClasses:
        list.sort((a, b) => b.classCount.compareTo(a.classCount));
    }
    return list;
  }

  /// Distinct industry names present in the catalog, sorted for the filter row.
  List<String> get _industryNames {
    final set = <String>{};
    for (final c in _all) {
      set.addAll(c.industries);
    }
    final list = set.toList()..sort();
    return list;
  }

  int _industryCount(String? name) => name == null
      ? _all.length
      : _all.where((c) => c.industries.contains(name)).length;

  bool get _hasFilters => _industry != null || _query.trim().isNotEmpty;

  // ---- Mutations: change state, reset paging ------------------------------
  void _apply(VoidCallback mutate) {
    setState(() {
      mutate();
      _visible = _pageSize;
    });
  }

  void _clearAll() {
    _searchCtrl.clear();
    _apply(() {
      _query = '';
      _industry = null;
    });
  }

  void _toggleSaved(String id) {
    final saved = !_saved.contains(id);
    setState(() => saved ? _saved.add(id) : _saved.remove(id));
    _soon(context, saved ? 'Saved to your list' : 'Removed from your list');
  }

  void _goHome() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
      );
    }
  }

  Future<void> _openPreview(_Course course) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _CoursePreviewSheet(
        course: course,
        initialSaved: _saved.contains(course.id),
        // Route through _toggleSaved so saving from the sheet gives the same
        // snackbar feedback as saving from a card.
        onToggleSaved: _toggleSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final total = results.length;
    final visible = results.take(_visible).toList();
    final hasCourses = !_loading && _error == null && _all.isNotEmpty;

    final content = Column(
      children: [
        if (!widget.embedded) const SizedBox(height: Bp.navHeight),
        _Header(
          count: _all.length,
          fields: _industryNames.length,
          loading: _loading,
          controller: _searchCtrl,
          query: _query,
          onQuery: (v) => _apply(() => _query = v),
          onClear: () {
            _searchCtrl.clear();
            _apply(() => _query = '');
          },
        ),
        _Bounded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCourses) ...[
                _IndustryFilter(
                  names: _industryNames,
                  selected: _industry,
                  countFor: _industryCount,
                  onSelect: (i) => _apply(() => _industry = i),
                ),
                const SizedBox(height: 22),
                _ControlBar(
                  total: total,
                  query: _query,
                  sort: _sort,
                  onSort: (s) => _apply(() => _sort = s),
                ),
                const SizedBox(height: 20),
              ],
              KeyedSubtree(key: _gridKey, child: _gridArea(total, visible)),
              if (hasCourses && _visible < total) ...[
                const SizedBox(height: 26),
                Center(
                  child: _PillButton(
                    'Load more courses',
                    kind: _BtnKind.ghost,
                    onPressed: () => setState(() => _visible += _pageSize),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Showing ${visible.length} of $total',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        ),
        if (!widget.embedded) const _Footer(),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(child: content),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ExploreTopNav(onBack: _goHome),
          ),
        ],
      ),
    );
  }

  // The stateful middle of the page: skeleton while loading, an error panel on
  // failure, an "empty catalog" state when nothing is shared yet, a "no match"
  // state when filters exclude everything, else the grid.
  Widget _gridArea(int total, List<_Course> visible) {
    if (_loading) return const _SkeletonGrid();
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);
    if (_all.isEmpty) return const _EmptyState.catalog();
    if (visible.isEmpty) {
      return _EmptyState.noMatch(
        query: _query,
        hasFilters: _hasFilters,
        onClearAll: _clearAll,
        onDropIndustry: () => _apply(() => _industry = null),
        industryActive: _industry != null,
      );
    }
    return _CourseGrid(
      courses: visible,
      saved: _saved,
      onSave: _toggleSaved,
      onOpen: _openPreview,
    );
  }
}
