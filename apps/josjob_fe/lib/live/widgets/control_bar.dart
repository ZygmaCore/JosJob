part of '../live_call_page.dart';

// =========================================================================
// Bottom control bar: mic / camera / screen (web publishers), raise-hand,
// host "end for all", and leave. Publishers see media toggles; view-only
// participants (classroom guests) see only raise-hand + leave.
// =========================================================================
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.controller, required this.onLeave});

  final LiveSessionController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          if (c.isPublisher) ...[
            _CircleButton(
              icon: c.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: 'Mikrofon',
              off: !c.micOn,
              onTap: c.toggleMic,
            ),
            _CircleButton(
              icon: c.camOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Kamera',
              off: !c.camOn,
              onTap: c.toggleCam,
            ),
            if (c.canScreenShare)
              _CircleButton(
                icon: c.isSharingScreen
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                label: 'Layar',
                active: c.isSharingScreen,
                onTap: c.toggleScreenShare,
              ),
          ],
          _CircleButton(
            icon: Icons.back_hand_outlined,
            label: 'Angkat tangan',
            active: c.handRaised,
            onTap: c.toggleHand,
          ),
          if (c.role == ParticipantRole.host)
            _CircleButton(
              icon: Icons.call_end_rounded,
              label: 'Akhiri',
              danger: true,
              onTap: () async {
                await c.endForAll();
                onLeave();
              },
            ),
          _CircleButton(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            danger: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.off = false,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool off;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color bg = danger
        ? _danger
        : off
        ? const Color(0xFF2A3A4D)
        : active
        ? AppColors.brandBlue
        : const Color(0xFF203449);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: _poppins(11, weight: FontWeight.w400, color: Colors.white70),
        ),
      ],
    );
  }
}
