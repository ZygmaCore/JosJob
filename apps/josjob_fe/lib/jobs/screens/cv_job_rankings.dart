part of '../jobs_page.dart';

/// Upload, review extracted skills, and inspect explainable best-fit roles.
class CvJobRankings extends StatefulWidget {
  final String? savedCvId;
  final List<String> savedCategories;
  final bool checkingSavedCv, savedCvUnavailable;
  final VoidCallback? onRetrySavedCv;
  final JobRankingsApi? api;
  final JobAuthorizer? authorize;
  final Future<PlatformFile?> Function()? pickPdf;
  final ValueChanged<Map<String, dynamic>>? onProfileReady;
  const CvJobRankings({
    super.key,
    this.api,
    this.savedCvId,
    this.savedCategories = const [],
    this.checkingSavedCv = false,
    this.savedCvUnavailable = false,
    this.onRetrySavedCv,
    this.authorize,
    this.pickPdf,
    this.onProfileReady,
  });
  @override
  State<CvJobRankings> createState() => _CvJobRankingsState();
}

class _CvJobRankingsState extends State<CvJobRankings> {
  late final _api = widget.api ?? JobRankingsApi();
  bool _consent = false, _busy = false, _replacing = false;
  String? _error, _id, _filename, _confirmedCvId;
  List<String> _confirmedCategories = const [];
  Map<String, dynamic>? _extraction, _ranking;
  Timer? _poll;
  DateTime? _started;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);

  @override
  void dispose() {
    _poll?.cancel();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _upload() async {
    try {
      final file = widget.pickPdf != null
          ? await widget.pickPdf!()
          : (await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              withData: true,
            ))?.files.single;
      if (!mounted || file == null) return;
      if (file.bytes == null) {
        throw const RankingException('Please select the PDF again.');
      }
      setState(() {
        _busy = true;
        _replacing = true;
        _error = null;
        _ranking = null;
        _extraction = null;
        _id = null;
        _filename = file.name;
      });
      final data = await _auth(
        (t) => _api.upload(t, file.bytes!, file.name, consent: _consent),
      );
      if (!mounted) return;
      _id = data['id'] as String;
      _started = DateTime.now();
      setState(() => _extraction = data);
      await _refresh();
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error.toString();
    });
  }

  Future<void> _refresh() async {
    _poll?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _auth((t) => _api.extraction(t, _id!));
      if (!mounted) return;
      setState(() => _extraction = data);
      final status = data['status'];
      if (status == 'done' || status == 'partial') {
        setState(() => _busy = false);
      } else if (status == 'queued' || status == 'processing') {
        if (DateTime.now().difference(_started!) >
            const Duration(minutes: 10)) {
          throw const RankingException(
            'Analysis is taking longer than expected. Check progress again shortly.',
          );
        }
        _poll = Timer(const Duration(seconds: 2), _refresh);
      } else {
        throw const RankingException(
          'Your CV could not be read. Upload a clearer PDF with selectable text.',
        );
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _rank() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cvId = _ranking?['cv_id'] as String?;
      final result = await _auth(
        (t) => cvId != null && _ranking?['persisted'] == true
            ? _api.rankSaved(t, cvId)
            : _api.rank(t, _id!),
      );
      if (mounted) {
        setState(() {
          _ranking = result;
          _busy = false;
          if (result['persisted'] == true) {
            _replacing = false;
            _confirmedCvId = result['cv_id'] as String?;
            _confirmedCategories = List<String>.from(
              (result['profile'] as Map?)?['categories'] as List? ?? [],
            );
          }
        });
        if (result['persisted'] == true) widget.onProfileReady?.call(result);
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.authorize != null || Session.instance.isSignedIn;
    final result = _extraction?['result'] as Map<String, dynamic>?;
    final skills = (result?['skills'] as List? ?? [])
        .map((s) => s is Map ? s['name'].toString() : s.toString())
        .toList();
    final ready = ['done', 'partial'].contains(_extraction?['status']);
    final saved = widget.savedCvId != null || _confirmedCvId != null;
    final showSaved = signedIn && saved && !_replacing;
    final checking = signedIn && widget.checkingSavedCv && !saved;
    final unavailable = signedIn && widget.savedCvUnavailable && !saved;
    final categories = widget.savedCvId != null
        ? widget.savedCategories
        : _confirmedCategories;
    return Container(
      key: const ValueKey('cv-job-rankings'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            showSaved
                ? 'Your CV is ready'
                : checking
                ? 'Checking your saved CV'
                : unavailable
                ? 'CV status unavailable'
                : 'Find the jobs that fit your CV',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showSaved
                ? 'Your saved CV is available for matching jobs.'
                : checking
                ? 'Loading your saved matching profile...'
                : unavailable
                ? 'Your saved CV could not be checked. Please try again.'
                : 'Upload your CV to see the most relevant jobs first.',
          ),
          if (!signedIn) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Sign in to match your CV'),
              ),
            ),
          ] else if (checking) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(key: ValueKey('cv-state-loading')),
          ] else if (unavailable) ...[
            const SizedBox(height: 12),
            if (widget.onRetrySavedCv != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('retry-cv-state'),
                  onPressed: widget.onRetrySavedCv,
                  child: const Text('Try again'),
                ),
              ),
          ] else if (showSaved) ...[
            const SizedBox(height: 12),
            Wrap(
              key: const ValueKey('cv-saved-ready'),
              spacing: 6,
              runSpacing: 6,
              children: categories
                  .map(
                    (value) => Chip(
                      label: Text(AppFormats.label(value.replaceAll('_', ' '))),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('change-ranking-cv'),
                onPressed: () => setState(() {
                  _replacing = true;
                  _consent = false;
                }),
                icon: const Icon(Icons.upload_file),
                label: const Text('Change CV'),
              ),
            ),
          ] else ...[
            if (saved && _replacing && !_busy)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('cancel-cv-replacement'),
                  onPressed: () => setState(() {
                    _replacing = false;
                    _error = null;
                    _extraction = null;
                    _id = null;
                    _filename = null;
                    _consent = false;
                  }),
                  child: const Text('Keep current CV'),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const ValueKey('cv-processing-consent'),
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _consent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to process my CV to find job matches.',
                ),
                subtitle: const Text(
                  'CV content may be sent to Gemini or a configured AI provider. Extraction is temporary; structured CV data and ranking results may be saved to your account.',
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('upload-ranking-cv'),
                  onPressed: _consent && !_busy ? _upload : null,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_id == null ? 'Upload PDF CV' : 'Replace PDF'),
                ),
                if (_filename != null) Text(_filename!),
                if (_id != null && !ready && !_busy)
                  TextButton(
                    onPressed: () {
                      _started = DateTime.now();
                      _refresh();
                    },
                    child: const Text('Check progress'),
                  ),
                if (ready)
                  OutlinedButton.icon(
                    key: const ValueKey('rank-cv-jobs'),
                    onPressed: _busy ? null : _rank,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _ranking == null
                          ? 'Use this CV for job listings'
                          : 'Refresh job relevance',
                    ),
                  ),
              ],
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Ranking opportunities...'
                  : 'Reading your CV. This may take a few minutes.',
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('ranking-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (ready && !showSaved) ...[
            const SizedBox(height: 16),
            Text(
              _extraction?['status'] == 'partial'
                  ? 'Part of your CV was read. Check these skills before matching.'
                  : 'Extracted skills: check before matching.',
            ),
            const SizedBox(height: 8),
            if (skills.isEmpty)
              const Text(
                'No skills were extracted. Matches will rely on the available experience and education.',
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills.map((s) => Chip(label: Text(s))).toList(),
            ),
            Text(
              'Extraction: ${_extraction?['provider'] ?? 'unknown'} / ${_extraction?['model'] ?? 'unknown'}',
            ),
            if ((_extraction?['warnings'] as List? ?? []).isNotEmpty)
              Text((_extraction!['warnings'] as List).join(' | ')),
          ],
          if (_ranking != null && !showSaved) ...[
            const SizedBox(height: 16),
            Text(
              'CV categories: ${((_ranking!['profile'] as Map?)?['categories'] as List? ?? []).join(', ').replaceAll('_', ' ')}',
            ),
            const Text(
              'Categories and required skills determine relevance. Newer jobs break ties. No AI calls are used for job comparisons.',
            ),
            if (_ranking!['persisted'] == false)
              const Text(
                'Your CV could not be saved. Try again before using it to sort the job list.',
              )
            else
              const Text(
                'Your saved CV is ready. Relevant jobs appear first in the job list.',
              ),
          ],
        ],
      ),
    );
  }
}
