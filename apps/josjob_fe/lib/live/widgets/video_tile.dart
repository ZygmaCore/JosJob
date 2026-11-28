part of '../live_call_page.dart';

// =========================================================================
// One participant/screen cell: live video (or an avatar placeholder when the
// camera is off / no track yet) with name, mic, hand and host overlays.
// =========================================================================
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.tile});

  final LiveTile tile;

  @override
  Widget build(BuildContext context) {
    final showVideo = tile.renderer != null && !tile.camOff;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _tileBg,
          border: tile.hand
              ? Border.all(color: AppColors.orange, width: 2)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo)
              RTCVideoView(
                tile.renderer!,
                mirror: tile.isLocal && !tile.isScreen,
                objectFit: tile.isScreen
                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _placeholder(),
            Positioned(top: 8, right: 8, child: _badges()),
            Positioned(left: 8, right: 8, bottom: 8, child: _nameRow()),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.brandBlue,
            child: Text(
              _initials(tile.label),
              style: _poppins(18, weight: FontWeight.w600),
            ),
          ),
          if (tile.isScreen) ...[
            const SizedBox(height: 8),
            const Icon(
              Icons.screen_share_outlined,
              size: 18,
              color: Colors.white54,
            ),
          ],
        ],
      ),
    );
  }

  Widget _badges() {
    final chips = <Widget>[
      if (tile.hand)
        _chip(
          const Icon(Icons.back_hand_outlined, size: 14, color: Colors.white),
        ),
      if (tile.isHost)
        _chip(Text('Host', style: _poppins(10.5, weight: FontWeight.w600))),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          chips[i],
        ],
      ],
    );
  }

  Widget _chip(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _nameRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tile.micOff) ...[
            const Icon(
              Icons.mic_off_rounded,
              size: 14,
              color: Color(0xFFE5484D),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              tile.label,
              overflow: TextOverflow.ellipsis,
              style: _poppins(12, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
