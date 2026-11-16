part of '../dashboard_page.dart';

// =========================================================================
// Coach browser (Live Coaching → Explore coaches): a live search field, a
// focus-area filter chip row, a sort control and a responsive results grid.
// Search and sort run client-side over the sample coach list — there is no
// backend. Shows a friendly empty state, with a "Clear filters" action, when
// nothing matches.
// =========================================================================
class _CoachBrowser extends StatefulWidget {
  final List<_Coach> coaches;
  const _CoachBrowser(this.coaches);

  @override
  State<_CoachBrowser> createState() => _CoachBrowserState();
}

class _CoachBrowserState extends State<_CoachBrowser> {
  final _controller = TextEditingController();
  String _query = '';
  _CoachFocus? _focus;
  _CoachSort _sort = _CoachSort.topRated;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Focus filter + free-text match (name / expertise / tagline / focus),
  // then ordered by the active sort.
  List<_Coach> get _results {
    final q = _query.trim().toLowerCase();
    final list = widget.coaches.where((c) {
      if (_focus != null && c.focus != _focus) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.expertise.toLowerCase().contains(q) ||
          c.tagline.toLowerCase().contains(q) ||
          c.focus.label.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case _CoachSort.topRated:
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : b.sessions.compareTo(a.sessions);
        case _CoachSort.mostSessions:
          return b.sessions.compareTo(a.sessions);
      }
    });
    return list;
  }

  void _clearAll() {
    setState(() {
      _controller.clear();
      _query = '';
      _focus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoachSearchField(
          controller: _controller,
          query: _query,
          onChanged: (v) => setState(() => _query = v),
          onClear: () => setState(() {
            _controller.clear();
            _query = '';
          }),
        ),
        const SizedBox(height: 16),
        _CoachFocusChips(
          selected: _focus,
          onSelected: (f) => setState(() => _focus = f),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                '${results.length} '
                '${results.length == 1 ? 'coach' : 'coaches'}',
                style: _tabular(
                  GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.body,
                  ),
                ),
              ),
            ),
            _CoachSortControl(
              value: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No coaches found',
              subtitle:
                  'Try a different search, or clear your filters to see every coach.',
              actionLabel: 'Clear filters',
              onAction: _clearAll,
            ),
          )
        else
          _CoachGrid(results),
      ],
    );
  }
}

// Responsive grid of coach cards: 2-up when wide, else stacked.
class _CoachGrid extends StatelessWidget {
  final List<_Coach> coaches;
  const _CoachGrid(this.coaches);

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
            for (final coach in coaches)
              SizedBox(width: itemW, child: _CoachCard(coach)),
          ],
        );
      },
    );
  }
}
