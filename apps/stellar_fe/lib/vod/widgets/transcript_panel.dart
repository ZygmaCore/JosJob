part of '../vod_page.dart';

// =========================================================================
// The transcript: timestamped paragraphs. The active paragraph highlights and
// auto-scrolls into view as playback advances; tapping a paragraph seeks to it.
// =========================================================================
class _TranscriptPanel extends StatefulWidget {
  final List<TranscriptSegment> segments;
  final int activeIndex;
  final ValueChanged<num> onSeekSeconds;

  const _TranscriptPanel({
    required this.segments,
    required this.activeIndex,
    required this.onSeekSeconds,
  });

  @override
  State<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<_TranscriptPanel> {
  final ScrollController _scroll = ScrollController();
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.segments.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _TranscriptPanel old) {
    super.didUpdateWidget(old);
    if (widget.segments.length != _keys.length) {
      _keys = List.generate(widget.segments.length, (_) => GlobalKey());
    }
    if (widget.activeIndex != old.activeIndex) _scrollToActive();
  }

  // Bring the active paragraph into view. On a far jump (seek / topic tap) the
  // target row may not be built yet — ListView.builder only builds near the
  // viewport, so its context is null. In that case jump to an approximate
  // offset first to force it to build, then ensure-visible on the next frame.
  // Instant under reduced motion.
  void _scrollToActive() {
    final i = widget.activeIndex;
    if (i < 0 || i >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ensureVisibleAt(i)) return;
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final approx = ((i / _keys.length) * max).clamp(0.0, max);
      _scroll.jumpTo(approx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureVisibleAt(i);
      });
    });
  }

  // ensure-visible the row at [i] if it is currently built; returns whether it
  // was (false means the row is off-screen and not yet in the widget tree).
  bool _ensureVisibleAt(int i) {
    final ctx = _keys[i].currentContext;
    if (ctx == null) return false;
    Scrollable.ensureVisible(
      ctx,
      duration: _anim(context, 300),
      alignment: 0.35,
      curve: Curves.easeOut,
    );
    return true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) {
      return const _PanelEmpty(
        icon: Icons.subject_rounded,
        text: 'No transcript is available for this video.',
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      itemCount: widget.segments.length,
      itemBuilder: (context, i) {
        final seg = widget.segments[i];
        final active = i == widget.activeIndex;
        return KeyedSubtree(
          key: _keys[i],
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: active ? AppColors.tintBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                focusColor: AppColors.focus,
                onTap: () => widget.onSeekSeconds(seg.startSeconds),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtTime(Duration(seconds: seg.startSeconds.round())),
                        style: _tabular(
                          GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? AppColors.brandBlue
                                : AppColors.body.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        seg.text,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          height: 1.55,
                          fontWeight: active
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: active ? AppColors.ink : AppColors.body,
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
    );
  }
}
