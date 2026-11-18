import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:josjob_fe/services/auth_api.dart';
import 'package:josjob_fe/services/live_coaching_api.dart';

Map<String, dynamic> profileJson({String status = 'approved'}) => {
  'id': 'coach-1',
  'display_name': 'Independent Coach',
  'headline': 'Career and interview coaching',
  'bio': 'Personal career guidance for graduates.',
  'expertise': ['Interviews', 'Career planning'],
  'session_minutes': 30,
  'status': status,
  'price_cents': 0,
};
Map<String, dynamic> coachingJson({
  bool configured = false,
  bool booked = false,
  bool own = false,
  bool canJoin = false,
}) {
  final now = DateTime.now().toUtc();
  final slot = {
    'id': 'slot-1',
    'starts_at': now.add(const Duration(days: 1)).toIso8601String(),
    'ends_at': now.add(const Duration(days: 1, minutes: 30)).toIso8601String(),
    'booked': false,
  };
  return {
    'live_configured': configured,
    'coaches': [
      {
        ...profileJson(),
        'slots': booked ? [] : [slot],
      },
    ],
    'my_profile': own ? profileJson(status: 'pending') : null,
    'my_slots': own ? [slot] : [],
    'bookings': booked
        ? [
            {
              'id': 'booking-1',
              'coach_name': 'Independent Coach',
              'learner_name': 'Learner',
              'starts_at':
                  (canJoin
                          ? now.subtract(const Duration(minutes: 5))
                          : now.add(const Duration(days: 1)))
                      .toIso8601String(),
              'ends_at':
                  (canJoin
                          ? now.add(const Duration(minutes: 25))
                          : now.add(const Duration(days: 1, minutes: 30)))
                      .toIso8601String(),
              'status': 'confirmed',
              'role': 'guest',
              'room_id': 'coaching:booking-1:one_on_one',
              'can_join': canJoin,
              'can_cancel': true,
              'can_complete': false,
              'price_cents': 0,
            },
          ]
        : [],
  };
}

void main() {
  test(
    'reads independent profiles and sends booking, profile and availability mutations with bearer auth',
    () async {
      final requests = <http.Request>[];
      final api = LiveCoachingApi(
        baseUrl: 'http://test',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(
              r.method == 'GET'
                  ? {'data': coachingJson(booked: true)}
                  : {'ok': true},
            ),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final result = await api.fetch('token');
      expect(result.coaches.single.expertise, [
        'Interviews',
        'Career planning',
      ]);
      expect(result.bookings.single.roomId, 'coaching:booking-1:one_on_one');
      await api.book('token', 'slot-1');
      await api.changeBooking('token', 'booking-1', 'cancel');
      await api.saveProfile('token', {'display_name': 'Coach'});
      await api.createSlot('token', DateTime.utc(2099, 1, 1));
      expect(requests.map((r) => r.method), [
        'GET',
        'POST',
        'PATCH',
        'PUT',
        'POST',
      ]);
      expect(
        requests.every((r) => r.headers['authorization'] == 'Bearer token'),
        isTrue,
      );
      expect(jsonDecode(requests[1].body), {'slot_id': 'slot-1'});
      expect(requests.every((r) => !r.url.path.contains('/classes')), isTrue);
    },
  );
  test(
    '401 supports refresh; conflicts and invalid payloads produce useful errors',
    () async {
      for (final status in [401, 409]) {
        final api = LiveCoachingApi(
          client: MockClient(
            (_) async => http.Response('{"error":"slot_unavailable"}', status),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetch('t'),
          throwsA(
            status == 401 ? isA<AuthException>() : isA<LiveCoachingException>(),
          ),
        );
      }
      for (final body in ['<html>down</html>', '{"data":{}}']) {
        final api = LiveCoachingApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetch('t'),
          throwsA(isA<LiveCoachingException>()),
        );
      }
    },
  );
}
