part of '../vod_page.dart';

// =========================================================================
// Play/pause + elapsed / total time + the checkpoint-aware seek bar.
// =========================================================================
class _PlayerControls extends StatelessWidget {
  final bool playing;
  final bool enabled;
  final Duration position;
  final Duration duration;
  final List<VideoCheckpoint> checkpoints;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  const _PlayerControls({
    required this.playing,
    required this.enabled,
    required this.position,
    required this.duration,
    required this.checkpoints,
    required this.onToggle,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final timeStyle = _tabular(
      GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.body,
      ),
    );

    return Row(
      children: [
        _RoundIconButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: playing ? 'Pause' : 'Play',
          onPressed: enabled ? onToggle : null,
        ),
        const SizedBox(width: 14),
        Text(_fmtTime(position), style: timeStyle),
        const SizedBox(width: 12),
        Expanded(
          child: _CheckpointSeekbar(
            position: position,
            duration: duration,
            checkpoints: checkpoints,
            enabled: enabled,
            onSeek: onSeek,
          ),
        ),
        const SizedBox(width: 12),
        Text(_fmtTime(duration), style: timeStyle),
      ],
    );
  }
}

// A 44×44 circular control button with a visible focus/hover state.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: onPressed == null ? AppColors.border : AppColors.brandBlue,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            focusColor: AppColors.focus,
            onTap: onPressed,
            child: Icon(
              icon,
              color: onPressed == null ? AppColors.body : Colors.white,
              size: 26,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}
