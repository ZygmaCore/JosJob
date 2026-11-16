part of '../live_call_page.dart';

// =========================================================================
// Arranges the call tiles: a shared screen (if any) takes the stage with a
// filmstrip of cameras; a 1-on-1 uses a speaker view with a local PiP; anything
// else uses a responsive grid.
// =========================================================================
class _ParticipantLayout extends StatelessWidget {
  const _ParticipantLayout({required this.tiles, required this.mode});

  final List<LiveTile> tiles;
  final LiveRoomMode mode;

  @override
  Widget build(BuildContext context) {
    final screens = tiles.where((t) => t.isScreen).toList();
    final cams = tiles.where((t) => !t.isScreen).toList();

    if (screens.isEmpty && cams.isEmpty) {
      return const _WaitingForOthers();
    }

    if (screens.isNotEmpty) {
      return _stageWithFilmstrip(stage: screens.first, strip: cams);
    }

    final remotes = cams.where((t) => !t.isLocal).toList();
    if (mode == LiveRoomMode.oneOnOne && remotes.isNotEmpty) {
      final local = cams.firstWhere(
        (t) => t.isLocal,
        orElse: () => remotes.first,
      );
      return _speakerView(
        main: remotes.first,
        pip: local.isLocal ? local : null,
      );
    }

    return _grid(cams);
  }

  Widget _stageWithFilmstrip({
    required LiveTile stage,
    required List<LiveTile> strip,
  }) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: _VideoTile(tile: stage),
          ),
        ),
        if (strip.isNotEmpty)
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: strip.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => AspectRatio(
                aspectRatio: 3 / 4,
                child: _VideoTile(tile: strip[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _speakerView({required LiveTile main, LiveTile? pip}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Stack(
        children: [
          Positioned.fill(child: _VideoTile(tile: main)),
          if (pip != null)
            Positioned(
              right: 12,
              bottom: 12,
              width: 116,
              height: 158,
              child: _VideoTile(tile: pip),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<LiveTile> cams) {
    final count = cams.length;
    final cross = count <= 1
        ? 1
        : count <= 4
        ? 2
        : 3;
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      crossAxisCount: cross,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 4 / 3,
      children: [for (final t in cams) _VideoTile(tile: t)],
    );
  }
}

class _WaitingForOthers extends StatelessWidget {
  const _WaitingForOthers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 44, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            'Menunggu peserta lain bergabung…',
            style: _poppins(14, weight: FontWeight.w400, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
