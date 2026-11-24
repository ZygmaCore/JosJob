import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:josjob_fe/services/ui_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthContinuation.clear();
  });

  test(
    'saved courses survive recreation and stay separate for each account',
    () async {
      await const UiPreferences().saveCourses('candidate', {
        'course-1',
        'course-2',
      });
      expect(await const UiPreferences().savedCourses('candidate'), {
        'course-1',
        'course-2',
      });
      expect(await const UiPreferences().savedCourses('employer'), isEmpty);
      await const UiPreferences().saveCourses('candidate', {'course-2'});
      expect(await const UiPreferences().savedCourses('candidate'), {
        'course-2',
      });
    },
  );

  test('auth return restores after reload and is consumed only once', () async {
    await AuthContinuation.remember('/jobs/job-1?apply=1');
    AuthContinuation.destination = null;
    await AuthContinuation.restore();
    expect(await AuthContinuation.take(), '/jobs/job-1?apply=1');
    await AuthContinuation.restore();
    expect(AuthContinuation.destination, isNull);
  });

  test(
    'job location and application drafts survive reload without crossing accounts or jobs',
    () async {
      const preferences = UiPreferences();
      await preferences.saveJobLocation('candidate', ' Bandung ');
      expect(
        await const UiPreferences().preferredJobLocation('candidate'),
        'Bandung',
      );
      expect(await preferences.preferredJobLocation('other'), '');
      await preferences.saveApplicationDraft('candidate', 'job-1', 'My draft');
      expect(
        await const UiPreferences().applicationDraft('candidate', 'job-1'),
        'My draft',
      );
      expect(await preferences.applicationDraft('candidate', 'job-2'), '');
      expect(await preferences.applicationDraft('other', 'job-1'), '');
      final writing = preferences.saveApplicationDraft(
        'candidate',
        'job-1',
        'Last edit',
      );
      final clearing = preferences.saveApplicationDraft(
        'candidate',
        'job-1',
        '',
      );
      await Future.wait([writing, clearing]);
      expect(await preferences.applicationDraft('candidate', 'job-1'), '');
    },
  );

  test(
    'an unfinished extraction is recoverable only for its account',
    () async {
      const preferences = UiPreferences();
      await preferences.savePendingCv('candidate', {
        'id': 'extraction-1',
        'filename': 'cv.pdf',
      });
      expect(
        (await const UiPreferences().pendingCv('candidate'))?['id'],
        'extraction-1',
      );
      expect(await preferences.pendingCv('other'), isNull);
      await preferences.savePendingCv('candidate', null);
      expect(await preferences.pendingCv('candidate'), isNull);
    },
  );

  test(
    'immediate sign-in consumption cannot leave a stale stored destination',
    () async {
      final writing = AuthContinuation.remember(
        '/dashboard?view=jobs&tab=applications',
      );
      expect(
        await AuthContinuation.take(),
        '/dashboard?view=jobs&tab=applications',
      );
      await writing;
      await AuthContinuation.restore();
      expect(AuthContinuation.destination, isNull);
    },
  );

  test('return destination rejects external and authentication URLs', () {
    for (final invalid in [
      'https://example.com',
      '//example.com/jobs',
      '/login',
      '/jobs#https://example.com',
      '/admin/teacher-invitations',
    ]) {
      expect(AuthContinuation.validate(invalid), isNull, reason: invalid);
    }
  });
}
