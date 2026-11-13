part of '../live_call_page.dart';

// =========================================================================
// Call chrome: dark scaffold that switches body by connection phase, with a
// top bar (mode + live participant count + leave) and the bottom control bar.
// =========================================================================
class _LiveScaffold extends StatelessWidget {
  const _LiveScaffold({required this.controller, required this.onLeave});

  final LiveSessionController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _callBg,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (controller.phase) {
      case ConnectionPhase.idle:
      case ConnectionPhase.connecting:
        return _LiveStatusView.connecting(onLeave: onLeave);
      case ConnectionPhase.notConfigured:
        return _LiveStatusView.notConfigured(onLeave: onLeave);
      case ConnectionPhase.error:
        return _LiveStatusView.error(
          message: controller.errorMessage,
          onLeave: onLeave,
        );
      case ConnectionPhase.ended:
        return _LiveStatusView.ended(
          removed: controller.removedByHost,
          onLeave: onLeave,
        );
      case ConnectionPhase.live:
        return _liveBody();
    }
  }

  Widget _liveBody() {
    return Column(
      children: [
        _TopBar(
          mode: controller.mode,
          count: controller.participantCount,
          onLeave: onLeave,
        ),
        if (controller.mediaDenied) const _MediaDeniedBanner(),
        Expanded(
          child: _ParticipantLayout(
            tiles: controller.tiles,
            mode: controller.mode,
          ),
        ),
        _ControlBar(controller: controller, onLeave: onLeave),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.count,
    required this.onLeave,
  });

  final LiveRoomMode mode;
  final int count;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3EA76A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.label, style: _poppins(15, weight: FontWeight.w600)),
                Text(
                  count == 1 ? 'Menunggu peserta lain' : '$count peserta',
                  style: _poppins(
                    12,
                    weight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Keluar',
          ),
        ],
      ),
    );
  }
}

class _MediaDeniedBanner extends StatelessWidget {
  const _MediaDeniedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFF2913D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kamera/mikrofon tidak tersedia — Anda bergabung dalam mode menonton.',
              style: _poppins(
                12.5,
                weight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
