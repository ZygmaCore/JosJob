part of '../vod_page.dart';

// =========================================================================
// Player shell: fetches the video, owns the VideoPlayerController + tab
// state, derives the active checkpoint/segment from the playhead, and lays
// out the stage + tabbed panel responsively.
// =========================================================================
class _VodShell extends StatefulWidget {
  final String? videoId;
  const _VodShell({this.videoId});

  @override
  State<_VodShell> createState() => _VodShellState();
}

class _VodShellState extends State<_VodShell>
    with SingleTickerProviderStateMixin {
  final VodApi _api = VodApi();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool _loading = true;
  String? _loadError;
  VodVideo? _video;

  VodPlayback? _player;
  bool _videoError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final video = await _resolveVideo();
      if (!mounted) return;
      setState(() {
        _video = video;
        _loading = false;
      });
      if (video.isReady && video.hlsUrl != null) {
        _initVideo(video.hlsUrl!);
      }
    } on VodException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  // With an explicit id, fetch it. Otherwise resolve the first ready video of
  // the first course (the '/vod' route + dashboard "Resume" with no deep-link).
  Future<VodVideo> _resolveVideo() async {
    final id = widget.videoId;
    if (id != null) return _api.fetchVideo(id);

    final courses = await _api.fetchCourses();
    if (courses.isEmpty) {
      throw const VodException('No videos are available yet.');
    }
    final course = await _api.fetchCourse(courses.first.id);
    if (course.videos.isEmpty) {
      throw const VodException('No videos are available yet.');
    }
    final target = course.videos.firstWhere(
      (l) => l.isReady,
      orElse: () => course.videos.first,
    );
    return _api.fetchVideo(target.id);
  }

  Future<void> _initVideo(String url) async {
    final player = createVodPlayback(url);
    _player = player;
    player.addListener(_onTick);
    try {
      await player.initialize();
      if (!mounted) return;
      setState(() {
        _duration = player.duration;
        if (player.hasError) _videoError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoError = true);
    }
  }

  void _onTick() {
    final p = _player;
    if (p == null || !mounted) return;
    setState(() {
      if (p.hasError) _videoError = true;
      _position = p.position;
      if (p.duration > Duration.zero) _duration = p.duration;
      _playing = p.isPlaying;
      _buffering = p.isBuffering;
    });
  }

  void _togglePlay() {
    final p = _player;
    if (p == null || !p.isInitialized) return;
    p.isPlaying ? p.pause() : p.play();
  }

  void _seek(Duration to) {
    final p = _player;
    if (p == null || !p.isInitialized) return;
    final clamped = to < Duration.zero
        ? Duration.zero
        : (to > _duration ? _duration : to);
    p.seekTo(clamped);
    setState(() => _position = clamped);
  }

  void _seekSeconds(num seconds) =>
      _seek(Duration(milliseconds: (seconds * 1000).round()));

  // Index of the checkpoint the playhead currently sits in (-1 before the
  // first). Checkpoints arrive sorted by start_seconds.
  int _activeCheckpoint(List<VideoCheckpoint> cps) {
    final pos = _position.inMilliseconds / 1000.0;
    var active = -1;
    for (var i = 0; i < cps.length; i++) {
      if (cps[i].startSeconds <= pos) active = i;
    }
    return active;
  }

  int _activeSegment(List<TranscriptSegment> segs) {
    final pos = _position.inMilliseconds / 1000.0;
    var active = -1;
    for (var i = 0; i < segs.length; i++) {
      if (segs[i].startSeconds <= pos) active = i;
    }
    return active;
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _tabs.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _VodTopBar(title: _video?.title ?? 'Video'),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const _VodLoading();
    if (_loadError != null) {
      return _VodMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load the video',
        message: _loadError!,
        onRetry: _load,
      );
    }

    final video = _video!;
    if (!video.isReady) {
      return _VodMessage(
        icon: video.isFailed
            ? Icons.error_outline_rounded
            : Icons.hourglass_top_rounded,
        title: video.isFailed
            ? 'This video failed to process'
            : 'This video is still processing',
        message: video.isFailed
            ? 'The video pipeline reported an error. Please try again later.'
            : 'The recording is being transcoded and transcribed (state: '
                  '${video.state}). Check back shortly.',
        onRetry: _load,
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= Bp.desktop;
    final activeCp = _activeCheckpoint(video.checkpoints);
    final activeSeg = _activeSegment(video.transcript);

    // Fall back to the backend duration until the video reports its own, so the
    // checkpoint markers + timeline are meaningful even before playback (and on
    // browsers that can't decode the HLS stream at all).
    final effectiveDuration = _duration > Duration.zero
        ? _duration
        : Duration(seconds: video.durationSeconds);

    Widget videoArea({required bool compact, double? maxStageHeight}) =>
        _VideoArea(
          player: _player,
          video: video,
          playing: _playing,
          buffering: _buffering,
          videoError: _videoError,
          position: _position,
          duration: effectiveDuration,
          onToggle: _togglePlay,
          onSeek: _seek,
          compact: compact,
          maxStageHeight: maxStageHeight,
        );

    final panel = _SidePanel(
      tabs: _tabs,
      video: video,
      activeCheckpoint: activeCp,
      activeSegment: activeSeg,
      onSeekSeconds: _seekSeconds,
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: videoArea(compact: false)),
          Container(width: 1, color: AppColors.border),
          SizedBox(width: _kPanelWidth, child: panel),
        ],
      );
    }

    // Mobile: cap the stage so the tabbed panel always fits (portrait &
    // landscape) — a non-flex scroll child would otherwise overflow the column.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            videoArea(
              compact: true,
              maxStageHeight: constraints.maxHeight * 0.52,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
