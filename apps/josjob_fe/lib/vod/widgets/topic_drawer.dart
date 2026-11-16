part of '../vod_page.dart';

// =========================================================================
// Table of contents of auto-generated checkpoints. The active one (where the
// playhead sits) is highlighted; tapping any row seeks the video to it.
// =========================================================================
class _TopicDrawer extends StatelessWidget {
  final List<VideoCheckpoint> checkpoints;
  final int activeIndex;
  final ValueChanged<num> onSeekSeconds;

  const _TopicDrawer({
    required this.checkpoints,
    required this.activeIndex,
    required this.onSeekSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (checkpoints.isEmpty) {
      return _PanelEmpty(
        icon: Icons.list_alt_outlined,
        text: 'No topics were generated for this video.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: checkpoints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final cp = checkpoints[i];
        final active = i == activeIndex;
        return Material(
          color: active ? AppColors.tintBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            focusColor: AppColors.focus,
            onTap: () => onSeekSeconds(cp.startSeconds),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.brandBlue : AppColors.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmtTime(Duration(seconds: cp.startSeconds)),
                      style: _tabular(
                        GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.body,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cp.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? AppColors.navy : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
