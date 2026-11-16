part of '../vod_page.dart';

// =========================================================================
// The tabbed companion panel: "Topics" (checkpoint table of contents) and
// "Transcript". A right column on desktop; stacked below the video on mobile.
// =========================================================================
class _SidePanel extends StatelessWidget {
  final TabController tabs;
  final VodVideo video;
  final int activeCheckpoint;
  final int activeSegment;
  final ValueChanged<num> onSeekSeconds;

  const _SidePanel({
    required this.tabs,
    required this.video,
    required this.activeCheckpoint,
    required this.activeSegment,
    required this.onSeekSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: tabs,
              labelColor: AppColors.brandBlue,
              unselectedLabelColor: AppColors.body,
              indicatorColor: AppColors.brandBlue,
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'Topics · ${video.checkpoints.length}'),
                const Tab(text: 'Transcript'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _TopicDrawer(
                  checkpoints: video.checkpoints,
                  activeIndex: activeCheckpoint,
                  onSeekSeconds: onSeekSeconds,
                ),
                _TranscriptPanel(
                  segments: video.transcript,
                  activeIndex: activeSegment,
                  onSeekSeconds: onSeekSeconds,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
