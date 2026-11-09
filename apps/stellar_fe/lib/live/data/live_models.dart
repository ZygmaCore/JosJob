import 'package:flutter_webrtc/flutter_webrtc.dart';

// =========================================================================
// ATVETI STELLAR — Live streaming models (Cloudflare Realtime SFU)
//
// Public, top-level (NOT a `part`) so both the live_session_controller and the
// part-based UI library can share them.
// =========================================================================

/// Session shape. Differs only in default publish + layout over one SFU core.
enum LiveRoomMode { oneOnOne, coaching, classroom }

/// Role in the room. v1: supplied by the entry point (client-trusted; the
/// backend documents this as a known gap to be replaced by server-derived role).
enum ParticipantRole { host, guest }

/// Connection lifecycle for the call screen.
enum ConnectionPhase { idle, connecting, live, notConfigured, error, ended }

extension LiveRoomModeX on LiveRoomMode {
  /// Wire value expected by the backend channel (`mode` join param).
  String get wire => switch (this) {
    LiveRoomMode.oneOnOne => 'one_on_one',
    LiveRoomMode.coaching => 'coaching',
    LiveRoomMode.classroom => 'classroom',
  };

  String get label => switch (this) {
    LiveRoomMode.oneOnOne => '1-on-1 session',
    LiveRoomMode.coaching => 'Coaching room',
    LiveRoomMode.classroom => 'Classroom',
  };
}

extension ParticipantRoleX on ParticipantRole {
  String get wire => this == ParticipantRole.host ? 'host' : 'guest';
}

/// Room id for a class-bound live session: `class:<classId>:<mode>`. The backend
/// (`StellarWeb.LiveRoomChannel`) parses the class id from this and GATES the join
/// by enrollment — only the class instructor (→ host) and active-enrolled students
/// (→ guest) may join; role is derived server-side. Teacher and student MUST build
/// the same id for a given class + type, so both go through this one helper.
String classRoomId(String classId, LiveRoomMode mode) =>
    'class:$classId:${mode.wire}';

ParticipantRole roleFromWire(String? v) =>
    v == 'host' ? ParticipantRole.host : ParticipantRole.guest;

/// Whether a participant with this [mode] + [role] publishes media. Only a
/// **classroom guest is view-only** (a broadcast viewer that pulls the host's
/// stream and uploads nothing); every other combination publishes camera + mic.
bool publishesMedia(LiveRoomMode mode, ParticipantRole role) =>
    !(mode == LiveRoomMode.classroom && role == ParticipantRole.guest);

/// A track a participant advertises via presence (name is globally unique:
/// `<participantId>:<mic|cam|screen>`).
class PublishedTrack {
  const PublishedTrack({required this.name, required this.kind});

  final String name;
  final String kind; // "audio" | "video" | "screen"

  static List<PublishedTrack> listFromMeta(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => PublishedTrack(
            name: '${m['name'] ?? ''}',
            kind: '${m['kind'] ?? 'video'}',
          ),
        )
        .where((t) => t.name.isNotEmpty)
        .toList(growable: false);
  }
}

/// A room participant, projected from a Phoenix.Presence meta.
class Participant {
  const Participant({
    required this.participantId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.sessionId,
    required this.tracks,
    required this.mic,
    required this.cam,
    required this.hand,
  });

  final String participantId;
  final String userId;
  final String displayName;
  final ParticipantRole role;

  /// Cloudflare SFU session id — the key a subscriber uses to pull this
  /// participant's tracks. Null until they publish.
  final String? sessionId;
  final List<PublishedTrack> tracks;
  final bool mic;
  final bool cam;
  final bool hand;

  bool get isHost => role == ParticipantRole.host;

  factory Participant.fromMeta(
    String participantId,
    Map<dynamic, dynamic> meta,
  ) {
    final sid = meta['sfu_session_id'];
    return Participant(
      participantId: participantId,
      userId: '${meta['user_id'] ?? ''}',
      displayName: '${meta['display_name'] ?? 'Peserta'}',
      role: roleFromWire(meta['role'] as String?),
      sessionId: (sid is String && sid.isNotEmpty) ? sid : null,
      tracks: PublishedTrack.listFromMeta(meta['tracks']),
      mic: meta['mic'] != false,
      cam: meta['cam'] != false,
      hand: meta['hand'] == true,
    );
  }
}

/// One rendered cell in the call grid. Built by the controller so the UI stays
/// declarative and never touches WebRTC objects directly.
class LiveTile {
  const LiveTile({
    required this.key,
    required this.label,
    required this.renderer,
    required this.isLocal,
    required this.isScreen,
    required this.micOff,
    required this.camOff,
    required this.hand,
    required this.isHost,
  });

  final String key;
  final String label;

  /// Renderer with live video, or null → show an avatar/placeholder tile.
  final RTCVideoRenderer? renderer;
  final bool isLocal;
  final bool isScreen;
  final bool micOff;
  final bool camOff;
  final bool hand;
  final bool isHost;
}
