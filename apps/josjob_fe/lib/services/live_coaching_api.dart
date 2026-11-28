import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_api.dart' show AuthException;

class LiveCoachingException implements Exception {
  final String message;
  final int? statusCode;
  const LiveCoachingException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class CoachSlot {
  final String id;
  final DateTime startsAt, endsAt;
  final bool booked;
  CoachSlot.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      startsAt = DateTime.parse(j['starts_at'] as String),
      endsAt = DateTime.parse(j['ends_at'] as String),
      booked = j['booked'] == true;
}

class CoachProfile {
  final String id, name, headline, bio, status;
  final int minutes;
  final List<String> expertise;
  final List<CoachSlot> slots;
  CoachProfile.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['display_name'] as String,
      headline = j['headline'] as String,
      bio = j['bio'] as String,
      status = j['status'] as String,
      minutes = (j['session_minutes'] as num).toInt(),
      expertise = List<String>.from(j['expertise'] as List),
      slots = (j['slots'] as List? ?? [])
          .map((v) => CoachSlot.fromJson(v as Map<String, dynamic>))
          .toList();
}

class CoachingBooking {
  final String id, coachName, learnerName, status, role, roomId;
  final DateTime startsAt, endsAt;
  final bool canJoin, canCancel, canComplete;
  CoachingBooking.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      coachName = j['coach_name'] as String,
      learnerName = j['learner_name'] as String,
      status = j['status'] as String,
      role = j['role'] as String,
      roomId = j['room_id'] as String,
      startsAt = DateTime.parse(j['starts_at'] as String),
      endsAt = DateTime.parse(j['ends_at'] as String),
      canJoin = j['can_join'] as bool,
      canCancel = j['can_cancel'] as bool,
      canComplete = j['can_complete'] as bool {
    if ((role != 'host' && role != 'guest') ||
        !roomId.startsWith('coaching:')) {
      throw const FormatException('Invalid booking admission');
    }
  }
  bool get host => role == 'host';
}

class LiveCoachingData {
  final bool configured;
  final List<CoachProfile> coaches;
  final List<CoachingBooking> bookings;
  final CoachProfile? myProfile;
  final List<CoachSlot> mySlots;
  LiveCoachingData.fromJson(Map<String, dynamic> j)
    : configured = j['live_configured'] as bool,
      coaches = (j['coaches'] as List)
          .map((v) => CoachProfile.fromJson(v as Map<String, dynamic>))
          .toList(),
      bookings = (j['bookings'] as List)
          .map((v) => CoachingBooking.fromJson(v as Map<String, dynamic>))
          .toList(),
      myProfile = j['my_profile'] == null
          ? null
          : CoachProfile.fromJson(j['my_profile'] as Map<String, dynamic>),
      mySlots = (j['my_slots'] as List)
          .map((v) => CoachSlot.fromJson(v as Map<String, dynamic>))
          .toList();
}

class LiveCoachingApi {
  final http.Client _client;
  final String _baseUrl;
  LiveCoachingApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;
  Future<LiveCoachingData> fetch(String token) async {
    try {
      return LiveCoachingData.fromJson(
        (await _send('GET', '/api/me/live-coaching', token))['data']
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const LiveCoachingException(
        'The server returned incomplete coaching data. Please try again.',
      );
    } on FormatException {
      throw const LiveCoachingException(
        'The server returned unreadable coaching data. Please try again.',
      );
    }
  }

  Future<void> saveProfile(String token, Map<String, dynamic> attrs) async {
    await _send('PUT', '/api/coaching/profile', token, attrs);
  }

  Future<void> createSlot(String token, DateTime startsAt) async {
    await _send('POST', '/api/coaching/slots', token, {
      'starts_at': startsAt.toUtc().toIso8601String(),
    });
  }

  Future<void> closeSlot(String token, String id) async {
    await _send(
      'DELETE',
      '/api/coaching/slots/${Uri.encodeComponent(id)}',
      token,
    );
  }

  Future<void> book(String token, String id) async {
    await _send('POST', '/api/coaching/bookings', token, {'slot_id': id});
  }

  Future<void> changeBooking(String token, String id, String action) async {
    await _send(
      'PATCH',
      '/api/coaching/bookings/${Uri.encodeComponent(id)}',
      token,
      {'action': action},
    );
  }

  Future<List<CoachProfile>> adminProfiles(String token) async =>
      ((await _send('GET', '/api/coaching/admin/profiles', token))['data']
              as List)
          .map((v) => CoachProfile.fromJson(v as Map<String, dynamic>))
          .toList();
  Future<void> review(String token, String id, String status) async {
    await _send(
      'PATCH',
      '/api/coaching/admin/profiles/${Uri.encodeComponent(id)}',
      token,
      {'status': status},
    );
  }

  void close() => _client.close();
  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String token, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'accept': 'application/json',
          'authorization': 'Bearer $token',
        });
      if (data != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const AuthException('Please sign in again.', statusCode: 401);
      }
      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const LiveCoachingException(
          'The server returned an unreadable response. Please try again.',
        );
      }
      if (response.statusCode >= 400) {
        final message = switch (body['error']) {
          'slot_unavailable' =>
            'This slot is no longer available. Refresh and choose another.',
          'overlap' =>
            'This time overlaps another availability slot or appointment.',
          'self_booking' => 'You cannot book your own coaching session.',
          'invalid_date' => 'Choose a future date and time.',
          'profile_required' => 'Create your coach profile first.',
          'forbidden' => 'You do not have permission for this action.',
          'not_found' => 'This item is no longer available.',
          'invalid_status' =>
            'This appointment cannot be changed in its current state.',
          'validation_failed' =>
            'Check the profile fields and session duration (15–120 minutes).',
          _ => 'Coaching could not be updated. Please try again.',
        };
        throw LiveCoachingException(message, statusCode: response.statusCode);
      }
      return body;
    } on AuthException {
      rethrow;
    } on LiveCoachingException {
      rethrow;
    } on TimeoutException {
      throw const LiveCoachingException(
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const LiveCoachingException('Check your connection and try again.');
    }
  }
}
