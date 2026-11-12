import 'dart:async';

import 'package:phoenix_socket/phoenix_socket.dart';

import '../../services/api_config.dart';
import '../../services/session.dart';

// =========================================================================
// JosJob — Live signaling client (Phoenix Channels)
//
// Thin wrapper over phoenix_socket for the `live_room:<id>` channel. Confines
// the phoenix_socket dependency to this file. All SFU calls are request/reply
// (channel.push(...).future); presence + server pushes come off channel.messages
// (parsed MANUALLY — PhoenixPresence is flagged experimental upstream).
//
// The JWT is supplied via dynamicParams so each (re)connect carries the current
// access token, and is NEVER put in the endpoint URL.
// =========================================================================

class LiveSignalingException implements Exception {
  const LiveSignalingException(this.reason);
  final String reason;
  @override
  String toString() => 'LiveSignalingException($reason)';
}

/// Reply to a channel join.
class JoinReply {
  const JoinReply({required this.configured, required this.participantId});

  final bool configured;
  final String participantId;

  factory JoinReply.fromMap(Map<String, dynamic> m) {
    final self = (m['self'] as Map?) ?? const {};
    return JoinReply(
      configured: m['configured'] == true,
      participantId: '${self['participant_id'] ?? ''}',
    );
  }
}

/// Result of a `sfu:pull` — an SFU offer (when renegotiation is required) plus
/// the trackName→mid mapping the client uses to match `onTrack` events.
class PullResult {
  const PullResult({
    required this.sdp,
    required this.renegotiate,
    required this.tracks,
  });

  final String? sdp;
  final bool renegotiate;
  final List<PulledTrack> tracks;

  factory PullResult.fromMap(Map<String, dynamic> m) {
    final tracks = (m['tracks'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (t) => PulledTrack(
            trackName: '${t['track_name'] ?? ''}',
            mid: t['mid'] as String?,
          ),
        )
        .toList(growable: false);
    return PullResult(
      sdp: m['sdp'] as String?,
      renegotiate: m['renegotiate'] == true,
      tracks: tracks,
    );
  }
}

class PulledTrack {
  const PulledTrack({required this.trackName, required this.mid});
  final String trackName;
  final String? mid;
}

/// A host directive received off the channel (targeting a participant).
class HostCommand {
  const HostCommand({required this.kind, required this.participantId});
  final HostCommandKind kind;
  final String participantId;
}

enum HostCommandKind { mute, remove }

class LiveSignalingClient {
  PhoenixSocket? _socket;
  PhoenixChannel? _channel;

  final _presenceState = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceDiff = StreamController<Map<String, dynamic>>.broadcast();
  final _roomEnded = StreamController<void>.broadcast();
  final _hostCommand = StreamController<HostCommand>.broadcast();
  final List<StreamSubscription> _subs = [];

  Stream<Map<String, dynamic>> get presenceState => _presenceState.stream;
  Stream<Map<String, dynamic>> get presenceDiff => _presenceDiff.stream;
  Stream<void> get roomEnded => _roomEnded.stream;
  Stream<HostCommand> get hostCommand => _hostCommand.stream;

  /// Derive the WebSocket endpoint from the REST base URL (http→ws / https→wss).
  static String wsEndpoint() {
    final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/socket/websocket';
  }

  Future<JoinReply> connectAndJoin({
    required String roomId,
    required String mode,
    required String role,
    required String displayName,
  }) async {
    final socket = PhoenixSocket(
      wsEndpoint(),
      socketOptions: PhoenixSocketOptions(
        dynamicParams: () async => {
          'token': Session.instance.accessToken ?? '',
        },
      ),
    );
    _socket = socket;
    await socket.connect();

    final channel = socket.addChannel(
      topic: 'live_room:$roomId',
      parameters: {'mode': mode, 'role': role, 'display_name': displayName},
    );
    _channel = channel;

    // Attach message demuxers BEFORE joining so the server's post-join
    // presence_state push is not missed.
    _on(channel, 'presence_state', (p) => _presenceState.add(p));
    _on(channel, 'presence_diff', (p) => _presenceDiff.add(p));
    _on(channel, 'room_ended', (_) => _roomEnded.add(null));
    _on(channel, 'host_mute', (p) => _emitHost(HostCommandKind.mute, p));
    _on(channel, 'host_remove', (p) => _emitHost(HostCommandKind.remove, p));

    final reply = await channel.join().future;
    if (!reply.isOk) {
      throw LiveSignalingException('join_failed:${_reason(reply.response)}');
    }
    return JoinReply.fromMap(_asMap(reply.response));
  }

  Future<List<dynamic>> iceServers() async =>
      (await _push('ice_servers', const {}))['ice_servers'] as List? ??
      const [];

  Future<String> newSession() async =>
      '${(await _push('sfu:session', const {}))['session_id']}';

  Future<String> publish(String sdp, List<Map<String, dynamic>> tracks) async =>
      '${(await _push('sfu:publish', {'sdp': sdp, 'tracks': tracks}))['sdp']}';

  Future<PullResult> pull(List<Map<String, dynamic>> tracks) async =>
      PullResult.fromMap(await _push('sfu:pull', {'tracks': tracks}));

  Future<void> renegotiate(String sdp) =>
      _push('sfu:renegotiate', {'sdp': sdp});

  Future<void> closeTracks(List<String> mids, List<String> names) =>
      _push('sfu:close', {'mids': mids, 'names': names});

  Future<void> updateState({bool? mic, bool? cam, bool? hand}) =>
      _push('state:update', {'mic': ?mic, 'cam': ?cam, 'hand': ?hand});

  Future<void> hostEnd() => _push('host:end', const {});
  Future<void> hostMute(String pid) =>
      _push('host:mute', {'participant_id': pid});
  Future<void> hostRemove(String pid) =>
      _push('host:remove', {'participant_id': pid});

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      _channel?.leave();
    } catch (_) {
      /* already gone */
    }
    _socket?.dispose();
    await _presenceState.close();
    await _presenceDiff.close();
    await _roomEnded.close();
    await _hostCommand.close();
  }

  // ---- internals ---------------------------------------------------------

  Future<Map<String, dynamic>> _push(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final channel = _channel;
    if (channel == null) throw const LiveSignalingException('not_joined');
    final resp = await channel.push(event, payload).future;
    if (resp.isOk) return _asMap(resp.response);
    throw LiveSignalingException(_reason(resp.response));
  }

  void _on(
    PhoenixChannel channel,
    String event,
    void Function(Map<String, dynamic>) handler,
  ) {
    _subs.add(
      channel.messages
          .where((m) => m.event.value == event)
          .listen((m) => handler(_asMap(m.payload))),
    );
  }

  void _emitHost(HostCommandKind kind, Map<String, dynamic> payload) {
    final pid = '${payload['participant_id'] ?? ''}';
    if (pid.isNotEmpty) {
      _hostCommand.add(HostCommand(kind: kind, participantId: pid));
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static String _reason(dynamic response) =>
      '${_asMap(response)['reason'] ?? 'error'}';
}
