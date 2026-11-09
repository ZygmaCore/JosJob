import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

// =========================================================================
// ATVETI STELLAR — Masterdata API client
//
// Read-only JSON client for the public reference-data endpoints:
//   GET /api/industries  -> {data:[{id,name,parent_id,parent}]}
//   GET /api/countries   -> {data:[{id,name,code,phone_code}]}
//   GET /api/skills      -> {data:[{id,name,industry_id,industry}]}
//   GET /api/professions -> {data:[{id,name}]}
//
// These are public (no auth token). The values feed the onboarding pickers.
// A failed call throws so the caller ([MasterData]) can fall back to its
// built-in defaults.
// =========================================================================

/// A masterdata industry. [parentId] is null for a top-level industry.
class Industry {
  final String id;
  final String name;
  final String? parentId;

  const Industry({required this.id, required this.name, this.parentId});

  factory Industry.fromJson(Map<String, dynamic> j) => Industry(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString().trim(),
    parentId: (j['parent_id'])?.toString(),
  );
}

/// A masterdata country. [code] is ISO 3166-1 alpha-2; [phoneCode] is the
/// nullable E.164 dial code (e.g. "+62").
class Country {
  final String id;
  final String name;
  final String code;
  final String? phoneCode;

  const Country({
    required this.id,
    required this.name,
    required this.code,
    this.phoneCode,
  });

  factory Country.fromJson(Map<String, dynamic> j) => Country(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString().trim(),
    code: (j['code'] ?? '').toString(),
    phoneCode: (j['phone_code'])?.toString(),
  );
}

/// A masterdata skill. [industryId] is null when the skill isn't grouped under
/// an industry.
class Skill {
  final String id;
  final String name;
  final String? industryId;

  const Skill({required this.id, required this.name, this.industryId});

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString().trim(),
    industryId: (j['industry_id'])?.toString(),
  );
}

/// A masterdata profession (job title).
class Profession {
  final String id;
  final String name;

  const Profession({required this.id, required this.name});

  factory Profession.fromJson(Map<String, dynamic> j) => Profession(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString().trim(),
  );
}

class MasterDataApi {
  MasterDataApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  Future<List<Industry>> fetchIndustries() async {
    final data = await _getData('/api/industries');
    return data.map(Industry.fromJson).toList();
  }

  Future<List<Country>> fetchCountries() async {
    final data = await _getData('/api/countries');
    return data.map(Country.fromJson).toList();
  }

  Future<List<Skill>> fetchSkills() async {
    final data = await _getData('/api/skills');
    return data.map(Skill.fromJson).toList();
  }

  Future<List<Profession>> fetchProfessions() async {
    final data = await _getData('/api/professions');
    return data.map(Profession.fromJson).toList();
  }

  void close() => _client.close();

  // ---- internals -------------------------------------------------------
  // GETs [path], expects a 2xx body of shape {"data": [ {...}, ... ]}, and
  // returns the decoded list of maps. Throws on network/timeout/non-2xx or a
  // malformed body.
  Future<List<Map<String, dynamic>>> _getData(String path) async {
    final res = await _client
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('GET $path failed (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    final list = decoded is Map ? decoded['data'] : null;
    if (list is! List) {
      throw const FormatException('Unexpected masterdata response shape');
    }
    return [
      for (final e in list)
        if (e is Map) e.map((k, v) => MapEntry(k.toString(), v)),
    ];
  }
}
