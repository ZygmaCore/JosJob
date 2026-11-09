import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_fe/services/masterdata_api.dart';
import 'package:stellar_fe/services/masterdata.dart';

// Headless unit tests for the industry-scoped skills logic: the /api/skills
// parse (industry_id) + the pure grouping/suggestion helpers that drive the
// onboarding "Skills related to industries" picker.
void main() {
  group('MasterDataApi.fetchSkills', () {
    test('parses industry_id from the /api/skills payload', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/skills');
        return http.Response(
          '{"data":['
          '{"id":"s1","name":"Carpentry","industry_id":"i-con",'
          '"industry":{"id":"i-con","name":"Construction & Trades"}},'
          '{"id":"s2","name":"Communication","industry_id":null}'
          ']}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final skills = await MasterDataApi(
        client: client,
        baseUrl: 'http://test.local',
      ).fetchSkills();

      expect(skills.map((s) => s.name).toList(), [
        'Carpentry',
        'Communication',
      ]);
      expect(skills[0].industryId, 'i-con');
      expect(skills[1].industryId, isNull);
    });
  });

  group('MasterData.groupSkills', () {
    test('splits general (no industry) from per-industry skills', () {
      final grouped = MasterData.groupSkills(const [
        Skill(id: 's1', name: 'Carpentry', industryId: 'i-con'),
        Skill(id: 's2', name: 'Welding', industryId: 'i-con'),
        Skill(id: 's3', name: 'Communication'),
        Skill(id: 's4', name: 'Patient Care', industryId: 'i-health'),
      ]);

      expect(grouped.general, ['Communication']);
      expect(grouped.byIndustry, {
        'i-con': ['Carpentry', 'Welding'],
        'i-health': ['Patient Care'],
      });
    });
  });

  group('MasterData.suggestFor', () {
    const general = ['Communication', 'Teamwork'];
    final byIndustry = {
      'i-con': ['Carpentry', 'Welding'],
    };

    test('no industry selected -> general skills only', () {
      expect(MasterData.suggestFor(general, byIndustry, null), general);
      expect(MasterData.suggestFor(general, byIndustry, ''), general);
    });

    test('known industry -> its skills then the general skills', () {
      expect(MasterData.suggestFor(general, byIndustry, 'i-con'), [
        'Carpentry',
        'Welding',
        'Communication',
        'Teamwork',
      ]);
    });

    test('unknown industry id -> general skills only', () {
      expect(MasterData.suggestFor(general, byIndustry, 'missing'), general);
    });
  });
}
