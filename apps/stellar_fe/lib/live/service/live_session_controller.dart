import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/live_models.dart';
import 'signaling_client.dart';

// =========================================================================
// ATVETI STELLAR — Live session controller (Cloudflare Realtime SFU client)
//
// One RTCPeerConnection + one SFU session per participant. Publishes local
// tracks (client = offerer) and pulls remote tracks (SFU = offerer) on the SAME
// PeerConnection. EVERY signalingState-mutating operation (publish, screen
// publish, batched pull) runs through ONE serialized queue — safe because
// Cloudflare never sends an unsolicited offer, so the client fully controls
// ordering. SDP is only sent AFTER ICE gathering (Cloudflare's SFU is ICE-lite
// and rejects candidate-less offers). Presence drives discovery of who to pull.
// =========================================================================

class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.roomId,
    required this.mode,
    required this.role,
    required this.displayName,
    LiveSignalingClient? signaling,
  }) : _sig = signaling ?? LiveSignalingClient();

  final String roomId;
  final LiveRoomMode mode;
  final ParticipantRole role;
  final String displayName;
  final LiveSignalingClient _sig;

  // ---- public state (read by the UI) ------------------------------------
  ConnectionPhase phase = ConnectionPhase.idle;
  String? errorMessage;
  bool mediaDenied = false;
  bool micOn = true;
  bool camOn = true;
  bool handRaised = false;
  bool endedByHost = false;
  bool removedByHost = false;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  /// Whether this participant publishes media (classroom guests are view-only).
  bool get isPublisher => publishesMedia(mode, role);

  bool get isSharingScreen => _screenStream != null;
  bool get canScreenShare =>
      kIsWeb && isPublisher && phase == ConnectionPhase.live;
  int get participantCount => _participants.length;

  // ---- internals --------------------------------------------------------
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  String? _mySessionId;
  String? myParticipantId;
  List<dynamic> _iceServers = const [];
  bool _localRendererReady = false;
  bool _disposed = false;

  // trackName -> mid (from pull responses) so onTrack can be matched.
  final Map<String, String> _midToTrack = {};

  // renderKey -> renderer. cam => participantId; screen => "<pid>:screen".
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  // participantId -> Participant (from presence).
  final Map<String, Participant> _participants = {};

  // "<sessionId>|<trackName>" already subscribed (idempotent, keyed by session
  // so a re-published name under a new session re-pulls).
  final Set<String> _subscribed = {};

  // mid of the local screen-share transceiver (to close it later).
  String? _screenMid;

  final List<StreamSubscription> _subs = [];

  // ---- lifecycle --------------------------------------------------------

  Future<void> connect() async {
    _set(ConnectionPhase.connecting);
    // Subscribe to signaling streams BEFORE joining so the post-join
    // presence_state push is captured.
    _subs.add(_sig.presenceState.listen(_onPresenceState));
    _subs.add(_sig.presenceDiff.listen(_onPresenceDiff));
    _subs.add(_sig.roomEnded.listen((_) => _onRoomEnded()));
    _subs.add(_sig.hostCommand.listen(_onHostCommand));

    try {
      final reply = await _sig.connectAndJoin(
        roomId: roomId,
        mode: mode.wire,
        role: role.wire,
        displayName: displayName,
      );
      if (_disposed) return;
      myParticipantId = reply.participantId;
      if (!reply.configured) {
        _set(ConnectionPhase.notConfigured);
        return;
      }

      _iceServers = await _sig.iceServers();
      await _createPeerConnection();
      _mySessionId = await _sig.newSession();

      if (isPublisher) {
        try {
          await _enqueue(_publishLocal);
        } catch (e) {
          // Publishing failed — keep going view-only rather than aborting.
          debugPrint('live: publish failed: $e');
        }
      }

      if (_disposed) return;
      _set(ConnectionPhase.live);
      _syncSubscriptions();
    } catch (e) {
      _fail('$e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    super.dispose();
  }

  Future<void> _teardown() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _stopStream(_localStream);
    await _stopStream(_screenStream);
    _localStream = null;
    _screenStream = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    if (_localRendererReady) {
      await localRenderer.dispose();
    }
    for (final r in _remoteRenderers.values) {
      await r.dispose();
    }
    _remoteRenderers.clear();
    await _sig.dispose();
  }

  // ---- negotiation serialization ----------------------------------------
  // ONE queue for EVERY signalingState-mutating op (publish, screen publish,
  // batched pull). Each job runs to completion before the next dequeues —
  // safe because Cloudflare never sends an unsolicited offer, so the client
  // fully controls ordering on the single shared PeerConnection.
  Future<void> _negoChain = Future.value();

  Future<void> _enqueue(Future<void> Function() job) {
    final completer = Completer<void>();
    _negoChain = _negoChain.then((_) async {
      if (_disposed) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
      try {
        await job();
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ---- actions ----------------------------------------------------------

  Future<void> toggleMic() async {
    micOn = !micOn;
    for (final t in _localStream?.getAudioTracks() ?? const []) {
      t.enabled = micOn;
    }
    _safeNotify();
    await _safeSignal(() => _sig.updateState(mic: micOn));
  }

  Future<void> toggleCam() async {
    camOn = !camOn;
    for (final t in _localStream?.getVideoTracks() ?? const []) {
      t.enabled = camOn;
    }
    _safeNotify();
    await _safeSignal(() => _sig.updateState(cam: camOn));
  }

  Future<void> toggleHand() async {
    handRaised = !handRaised;
    _safeNotify();
    await _safeSignal(() => _sig.updateState(hand: handRaised));
  }

  Future<void> toggleScreenShare() async {
    if (!canScreenShare) return;
    if (_screenStream == null) {
      try {
        final stream = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });
        _screenStream = stream;
        _safeNotify();
        await _enqueue(() => _publishScreen(stream));
      } catch (e) {
        debugPrint('live: screen share failed: $e');
        await _stopStream(_screenStream);
        _screenStream = null;
        _safeNotify();
      }
    } else {
      await _enqueue(_unpublishScreen);
    }
  }

  /// Host: end the session for everyone (best-effort broadcast).
  Future<void> endForAll() async {
    await _safeSignal(_sig.hostEnd);
  }

  // ---- peer connection setup --------------------------------------------

  Future<void> _createPeerConnection() async {
    if (!_localRendererReady) {
      await localRenderer.initialize();
      _localRendererReady = true;
    }
    final pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });
    pc.onTrack = _onTrack;
    pc.onConnectionState = (state) {
      if (_disposed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        errorMessage = 'Koneksi media terputus.';
      }
      _safeNotify();
    };
    _pc = pc;
  }

  Future<void> _publishLocal() async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    await _acquireLocalMedia();
    final local = _localStream;
    if (local == null) return; // view-only (media denied)

    final pending = <_PendingTrack>[];
    for (final track in local.getTracks()) {
      final isAudio = track.kind == 'audio';
      final tx = await pc.addTransceiver(
        track: track,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly,
          streams: [local],
        ),
      );
      pending.add(
        _PendingTrack(
          tx,
          '$myParticipantId:${isAudio ? 'mic' : 'cam'}',
          isAudio ? 'audio' : 'video',
        ),
      );
    }
    if (pending.isEmpty) return;

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _waitIceGathering(pc);

    // mid is only assigned after setLocalDescription.
    final tracks = <Map<String, dynamic>>[];
    for (final p in pending) {
      final mid = p.transceiver.mid;
      if (mid.isEmpty) continue;
      tracks.add({'mid': mid, 'trackName': p.trackName, 'kind': p.kind});
    }
    final sdp = await _localSdp(pc);
    final answer = await _sig.publish(sdp, tracks);
    if (_disposed) return;
    await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

  Future<void> _publishScreen(MediaStream stream) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    final video = stream.getVideoTracks();
    if (video.isEmpty) return;
    final track = video.first;
    // Stop sharing if the user ends capture from the browser UI.
    track.onEnded = () => unawaited(_enqueue(_unpublishScreen));

    final tx = await pc.addTransceiver(
      track: track,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.SendOnly,
        streams: [stream],
      ),
    );
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _waitIceGathering(pc);
    final mid = tx.mid;
    if (mid.isEmpty) return;
    _screenMid = mid;
    final sdp = await _localSdp(pc);
    final answer = await _sig.publish(sdp, [
      {'mid': mid, 'trackName': '$myParticipantId:screen', 'kind': 'screen'},
    ]);
    if (_disposed) return;
    await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

  Future<void> _unpublishScreen() async {
    final mid = _screenMid;
    if (mid != null) {
      await _safeSignal(
        () => _sig.closeTracks([mid], ['$myParticipantId:screen']),
      );
    }
    await _stopStream(_screenStream);
    _screenStream = null;
    _screenMid = null;
    _safeNotify();
  }

  // ---- subscribe (pull) --------------------------------------------------

  void _syncSubscriptions() {
    if (_disposed || _mySessionId == null) return;

    // Reconcile against currently-advertised tracks. A participant may stop
    // publishing a track (e.g. end screen-share) while staying in the room —
    // presence sends an UPDATE (not a leave), so _evict never runs. Prune the
    // dropped subscriptions + renderers here so a stale screen tile can't lock
    // the stage and a same-session re-publish re-pulls.
    final advertised = <String>{};
    final screenPids = <String>{};
    for (final p in _others) {
      final sid = p.sessionId;
      for (final t in p.tracks) {
        if (sid != null) advertised.add('$sid|${t.name}');
        if (t.name.endsWith(':screen')) screenPids.add(p.participantId);
      }
    }
    _subscribed.removeWhere((k) => !advertised.contains(k));
    _remoteRenderers.removeWhere((key, r) {
      // Screen renderers key on "<pid>:screen"; cam renderers (no ':') are
      // handled by _evict + the p.cam gate, so leave them alone here.
      final gone =
          key.contains(':') && !screenPids.contains(key.split(':').first);
      if (gone) unawaited(r.dispose());
      return gone;
    });

    final toPull = <Map<String, dynamic>>[];
    for (final p in _others) {
      final sid = p.sessionId;
      if (sid == null) continue;
      for (final t in p.tracks) {
        final key = '$sid|${t.name}';
        if (_subscribed.contains(key)) continue;
        _subscribed.add(key);
        toPull.add({'sessionId': sid, 'trackName': t.name});
      }
    }
    if (toPull.isNotEmpty) {
      // Fire-and-forget through the queue; _pull swallows its own errors.
      unawaited(_enqueue(() => _pull(toPull)));
    }
  }

  Future<void> _pull(List<Map<String, dynamic>> tracks) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    try {
      final result = await _sig.pull(tracks);
      for (final t in result.tracks) {
        final mid = t.mid;
        if (mid != null && mid.isNotEmpty) _midToTrack[mid] = t.trackName;
      }
      if (result.renegotiate && (result.sdp?.isNotEmpty ?? false)) {
        await pc.setRemoteDescription(
          RTCSessionDescription(result.sdp!, 'offer'),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await _waitIceGathering(pc);
        await _sig.renegotiate(await _localSdp(pc));
      }
    } catch (e) {
      // Roll back so a later presence diff retries these tracks.
      for (final t in tracks) {
        _subscribed.remove('${t['sessionId']}|${t['trackName']}');
      }
      debugPrint('live: pull failed: $e');
    }
  }

  void _onTrack(RTCTrackEvent event) {
    if (_disposed) return;
    final mid = event.transceiver?.mid;
    final trackName = mid == null ? null : _midToTrack[mid];
    if (trackName == null) return;
    unawaited(_attachRemote(trackName, event.track));
  }

  Future<void> _attachRemote(String trackName, MediaStreamTrack track) async {
    final segs = trackName.split(':');
    final isScreen = segs.length > 1 && segs[1] == 'screen';
    final renderKey = isScreen ? trackName : segs.first;

    // This runs fire-and-forget from onTrack; dispose()/_teardown or a peer
    // _evict can run during any await below and free this renderer. Re-check
    // liveness after each await and dispose a renderer we created on bail-out.
    var renderer = _remoteRenderers[renderKey];
    final created = renderer == null;
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (_disposed || _remoteRenderers.containsKey(renderKey)) {
        await renderer.dispose();
        return;
      }
      _remoteRenderers[renderKey] = renderer;
    }

    final stream =
        renderer.srcObject ?? await createLocalMediaStream(renderKey);
    if (_disposed || !identical(_remoteRenderers[renderKey], renderer)) {
      if (created) await renderer.dispose();
      return;
    }

    await stream.addTrack(track);
    if (_disposed || !identical(_remoteRenderers[renderKey], renderer)) {
      if (created) await renderer.dispose();
      return;
    }

    renderer.srcObject = stream;
    _safeNotify();
  }

  // ---- presence ----------------------------------------------------------

  void _onPresenceState(Map<String, dynamic> state) {
    _participants.clear();
    state.forEach((pid, entry) {
      final meta = _firstMeta(entry);
      if (meta != null) _participants[pid] = Participant.fromMeta(pid, meta);
    });
    _safeNotify();
    _syncSubscriptions();
  }

  void _onPresenceDiff(Map<String, dynamic> diff) {
    final joins = (diff['joins'] as Map?) ?? const {};
    final leaves = (diff['leaves'] as Map?) ?? const {};

    joins.forEach((pid, entry) {
      final meta = _firstMeta(entry);
      if (meta != null) {
        _participants['$pid'] = Participant.fromMeta('$pid', meta);
      }
    });

    leaves.forEach((pid, entry) {
      // A key in BOTH joins and leaves is an UPDATE, not a real departure.
      if (joins.containsKey(pid)) return;
      final meta = _firstMeta(entry);
      final sid = meta?['sfu_session_id'] as String?;
      _participants.remove('$pid');
      _evict('$pid', sid);
    });

    _safeNotify();
    _syncSubscriptions();
  }

  void _evict(String pid, String? sessionId) {
    if (sessionId != null) {
      _subscribed.removeWhere((k) => k.startsWith('$sessionId|'));
    }
    for (final key in [pid, '$pid:screen']) {
      final r = _remoteRenderers.remove(key);
      if (r != null) unawaited(r.dispose());
    }
  }

  void _onRoomEnded() {
    if (_disposed) return;
    endedByHost = true;
    _set(ConnectionPhase.ended);
  }

  void _onHostCommand(HostCommand cmd) {
    if (_disposed || cmd.participantId != myParticipantId) return;
    switch (cmd.kind) {
      case HostCommandKind.mute:
        if (micOn) unawaited(toggleMic());
      case HostCommandKind.remove:
        removedByHost = true;
        _set(ConnectionPhase.ended);
    }
  }

  // ---- helpers -----------------------------------------------------------

  Iterable<Participant> get _others =>
      _participants.values.where((p) => p.participantId != myParticipantId);

  /// Video cells for the UI (local + remote screens + remote cams).
  List<LiveTile> get tiles {
    final list = <LiveTile>[];

    if (isPublisher) {
      final hasVideo =
          camOn && (_localStream?.getVideoTracks().isNotEmpty ?? false);
      list.add(
        LiveTile(
          key: 'local',
          label: 'Anda',
          renderer: hasVideo ? localRenderer : null,
          isLocal: true,
          isScreen: false,
          micOff: !micOn,
          camOff: !hasVideo,
          hand: handRaised,
          isHost: role == ParticipantRole.host,
        ),
      );
    }

    for (final entry in _remoteRenderers.entries) {
      if (!entry.key.contains(':')) continue; // cam keys have no ':'
      final pid = entry.key.split(':').first;
      final p = _participants[pid];
      list.add(
        LiveTile(
          key: entry.key,
          label: '${p?.displayName ?? 'Peserta'} — layar',
          renderer: entry.value,
          isLocal: false,
          isScreen: true,
          micOff: false,
          camOff: false,
          hand: false,
          isHost: p?.isHost ?? false,
        ),
      );
    }

    for (final p in _others) {
      final r = _remoteRenderers[p.participantId];
      list.add(
        LiveTile(
          key: p.participantId,
          label: p.displayName,
          renderer: p.cam ? r : null,
          isLocal: false,
          isScreen: false,
          micOff: !p.mic,
          camOff: !p.cam || r == null,
          hand: p.hand,
          isHost: p.isHost,
        ),
      );
    }
    return list;
  }

  Future<void> _acquireLocalMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
    } catch (_) {
      // Camera denied/absent — try audio only so the user can still be heard.
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        camOn = false;
        mediaDenied = true;
      } catch (_) {
        // Fully denied — join view-only.
        _localStream = null;
        micOn = false;
        camOn = false;
        mediaDenied = true;
      }
    }
    if (_localStream != null) localRenderer.srcObject = _localStream;
    _safeNotify();
  }

  /// Resolve when ICE gathering completes or a 1s cap elapses, then the local
  /// SDP carries server-reflexive candidates the ICE-lite SFU requires.
  Future<void> _waitIceGathering(
    RTCPeerConnection pc, {
    int capMs = 1000,
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    Timer? timer;
    void finish() {
      if (!completer.isCompleted) {
        timer?.cancel();
        completer.complete();
      }
    }

    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) finish();
    };
    timer = Timer(Duration(milliseconds: capMs), finish);
    await completer.future;
  }

  Future<String> _localSdp(RTCPeerConnection pc) async {
    final desc = await pc.getLocalDescription();
    return desc?.sdp ?? '';
  }

  Future<void> _stopStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final t in stream.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  Map<dynamic, dynamic>? _firstMeta(dynamic entry) {
    if (entry is! Map) return null;
    final metas = entry['metas'];
    if (metas is List && metas.isNotEmpty && metas.first is Map) {
      return metas.first as Map;
    }
    return null;
  }

  Future<void> _safeSignal(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('live: signal failed: $e');
    }
  }

  void _set(ConnectionPhase p) {
    phase = p;
    _safeNotify();
  }

  void _fail(String message) {
    errorMessage = message;
    _set(ConnectionPhase.error);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

class _PendingTrack {
  _PendingTrack(this.transceiver, this.trackName, this.kind);
  final RTCRtpTransceiver transceiver;
  final String trackName;
  final String kind;
}
