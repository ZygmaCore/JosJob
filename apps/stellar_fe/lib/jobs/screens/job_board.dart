part of '../jobs_page.dart';

// =========================================================================
// The board: a search field over a scrollable list of AI-matched roles.
// Stateful only to hold the local search query. Tapping a role opens detail.
// =========================================================================
class _JobBoard extends StatefulWidget {
  const _JobBoard();

  @override
  State<_JobBoard> createState() => _JobBoardState();
}

class _JobBoardState extends State<_JobBoard> {
  String _query = '';

  List<_Job> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _jobs;
    return _jobs
        .where(
          (j) =>
              j.title.toLowerCase().contains(q) ||
              j.company.toLowerCase().contains(q) ||
              j.location.toLowerCase().contains(q),
        )
        .toList();
  }

  void _open(_Job job) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _JobDetailPage(job)));
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0.5,
        foregroundColor: AppColors.ink,
        title: Text(
          'Browse roles',
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
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _SearchField(onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 18),
                Text(
                  results.isEmpty
                      ? 'No roles match your search'
                      : '${results.length} roles matched to your profile',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 14),
                if (results.isEmpty)
                  const _EmptyResults()
                else
                  for (final job in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _JobCard(job: job, onTap: () => _open(job)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 44, color: AppColors.body),
          const SizedBox(height: 14),
          Text(
            'Try a different role, company or location.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
          ),
        ],
      ),
    );
  }
}
