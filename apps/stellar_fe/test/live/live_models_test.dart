import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_fe/live/data/live_models.dart';
import 'package:stellar_fe/live/service/signaling_client.dart';

// Deterministic, font-free, texture-free unit tests for the live module's pure
// parsing/derivation logic (google_fonts throws headless, so no widget tests).

void main() {
  group('live models', () {
    test('LiveRoomMode.wire maps to backend values', () {
      expect(LiveRoomMode.oneOnOne.wire, 'one_on_one');
      expect(LiveRoomMode.coaching.wire, 'coaching');
      expect(LiveRoomMode.classroom.wire, 'classroom');
    });

    test('roleFromWire defaults to guest', () {
      expect(roleFromWire('host'), ParticipantRole.host);
      expect(roleFromWire('guest'), ParticipantRole.guest);
      expect(roleFromWire(null), ParticipantRole.guest);
      expect(roleFromWire('bogus'), ParticipantRole.guest);
    });

    test(
      'publishesMedia: ONLY a classroom guest is view-only (broadcast viewer)',
      () {
        // Broadcaster + every 2-way role publish; only the classroom viewer does not.
        expect(
          publishesMedia(LiveRoomMode.classroom, ParticipantRole.host),
          isTrue,
        );
        expect(
          publishesMedia(LiveRoomMode.classroom, ParticipantRole.guest),
          isFalse,
        );
        expect(
          publishesMedia(LiveRoomMode.oneOnOne, ParticipantRole.host),
          isTrue,
        );
        expect(
          publishesMedia(LiveRoomMode.oneOnOne, ParticipantRole.guest),
          isTrue,
        );
        expect(
          publishesMedia(LiveRoomMode.coaching, ParticipantRole.host),
          isTrue,
        );
        expect(
          publishesMedia(LiveRoomMode.coaching, ParticipantRole.guest),
          isTrue,
        );
      },
    );

    test('Participant.fromMeta parses a full meta', () {
      final p = Participant.fromMeta('pid-1', {
        'user_id': 'u1',
        'display_name': 'Ana',
        'role': 'host',
        'sfu_session_id': 'sess-9',
        'tracks': [
          {'name': 'pid-1:cam', 'kind': 'video'},
          {'name': 'pid-1:mic', 'kind': 'audio'},
        ],
        'mic': false,
        'cam': true,
        'hand': true,
      });
      expect(p.userId, 'u1');
      expect(p.displayName, 'Ana');
      expect(p.role, ParticipantRole.host);
      expect(p.isHost, isTrue);
      expect(p.sessionId, 'sess-9');
      expect(p.tracks.map((t) => t.name), ['pid-1:cam', 'pid-1:mic']);
      expect(p.mic, isFalse);
      expect(p.cam, isTrue);
      expect(p.hand, isTrue);
    });

    test('Participant.fromMeta applies safe defaults', () {
      final p = Participant.fromMeta('pid-2', {});
      expect(p.role, ParticipantRole.guest);
      expect(p.sessionId, isNull); // no session until published
      expect(p.tracks, isEmpty);
      expect(p.mic, isTrue); // absent => not muted
      expect(p.cam, isTrue);
      expect(p.hand, isFalse);
    });

    test('Participant.fromMeta treats empty sfu_session_id as null', () {
      final p = Participant.fromMeta('pid-3', {'sfu_session_id': ''});
      expect(p.sessionId, isNull);
    });

    test('PublishedTrack.listFromMeta ignores malformed entries', () {
      final tracks = PublishedTrack.listFromMeta([
        {'name': 'a:cam', 'kind': 'video'},
        {'kind': 'audio'}, // no name -> dropped
        'garbage',
      ]);
      expect(tracks.length, 1);
      expect(tracks.single.name, 'a:cam');
    });
  });

  group('signaling parsing', () {
    test('wsEndpoint derives ws:// from the http base URL', () {
      // Default ApiConfig.baseUrl is http://localhost:4000.
      expect(
        LiveSignalingClient.wsEndpoint(),
        'ws://localhost:4000/socket/websocket',
      );
    });

    test('JoinReply.fromMap reads configured + participant id', () {
      final r = JoinReply.fromMap({
        'configured': true,
        'mode': 'coaching',
        'self': {'user_id': 'u1', 'participant_id': 'p9', 'role': 'host'},
      });
      expect(r.configured, isTrue);
      expect(r.participantId, 'p9');
    });

    test('PullResult.fromMap maps sdp, renegotiate flag and track mids', () {
      final r = PullResult.fromMap({
        'sdp': 'v=0-offer',
        'renegotiate': true,
        'tracks': [
          {'track_name': 'p1:cam', 'mid': '2'},
        ],
      });
      expect(r.sdp, 'v=0-offer');
      expect(r.renegotiate, isTrue);
      expect(r.tracks.single.trackName, 'p1:cam');
      expect(r.tracks.single.mid, '2');
    });

    test('PullResult.fromMap tolerates a minimal body', () {
      final r = PullResult.fromMap({});
      expect(r.renegotiate, isFalse);
      expect(r.tracks, isEmpty);
      expect(r.sdp, isNull);
    });
  });
}
