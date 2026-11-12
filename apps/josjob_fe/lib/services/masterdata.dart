import 'package:flutter/foundation.dart';

import 'masterdata_api.dart';

// =========================================================================
// JosJob — Masterdata cache
//
// App-wide cache of the backend reference lists (industries, countries,
// skills, professions) used by the onboarding pickers. Starts with built-in
// fallback lists so the UI is never empty, then upgrades to live data on the
// first [ensureLoaded] and notifies listeners so open screens rebuild.
//
// Exposes the option NAMES (what the pickers display + store) plus id lookups
// so a synced answer can reference the master-data row, not just its name, and
// a country's E.164 dial code for the phone field. Best-effort: if the backend
// is unreachable (or a table is unseeded) the fallback names stay in place, and
// ids are simply unavailable (lookups return null) until a live fetch lands.
// =========================================================================

// Offline fallbacks (mirror the values seeded on the backend). Shown until the
// live fetch lands, and kept if it never does. Ids are only known once fetched.
const _fallbackIndustries = <String>[
  'Hospitality & Tourism',
  'Construction & Trades',
  'Healthcare',
  'Manufacturing',
  'Software & IT',
  'Finance',
  'Retail & Sales',
  'Logistics & Transport',
];

const _fallbackCountries = <String>[
  'Indonesia',
  'Singapore',
  'Malaysia',
  'Australia',
  'Philippines',
  'Vietnam',
  'Thailand',
  'India',
  'United States',
  'United Kingdom',
  'Germany',
  'Netherlands',
  'Japan',
  'South Korea',
  'United Arab Emirates',
  'Saudi Arabia',
  'Canada',
  'New Zealand',
  'China',
  'Other',
];

const _fallbackSkills = <String>[
  'Communication',
  'Teamwork',
  'Customer Service',
  'Safety Compliance',
  'Microsoft Office',
  'Problem Solving',
  'Time Management',
  'Leadership',
];

const _fallbackProfessions = <String>[
  'Software Engineer',
  'Project Manager',
  'Data Analyst',
  'Registered Nurse',
  'Chef',
  'Electrician',
  'Accountant',
  'Sales Executive',
];

// Offline dial codes for the fallback countries so the phone country-code
// picker still works without a live fetch. Keyed by the fallback names above.
const _fallbackCountryPhone = <String, String>{
  'Indonesia': '+62',
  'Singapore': '+65',
  'Malaysia': '+60',
  'Australia': '+61',
  'Philippines': '+63',
  'Vietnam': '+84',
  'Thailand': '+66',
  'India': '+91',
  'United States': '+1',
  'United Kingdom': '+44',
  'Germany': '+49',
  'Netherlands': '+31',
  'Japan': '+81',
  'South Korea': '+82',
  'United Arab Emirates': '+971',
  'Saudi Arabia': '+966',
  'Canada': '+1',
  'New Zealand': '+64',
  'China': '+86',
};

class MasterData extends ChangeNotifier {
  MasterData._();

  static final MasterData instance = MasterData._();

  final MasterDataApi _api = MasterDataApi();

  List<String> _industries = _fallbackIndustries;
  List<String> _countries = _fallbackCountries;
  List<String> _skills = _fallbackSkills;
  List<String> _professions = _fallbackProfessions;

  // Skills grouped for the industry-scoped picker: skills with no industry are
  // "general" (always suggested); the rest are keyed by their industry id.
  List<String> _generalSkills = _fallbackSkills;
  Map<String, List<String>> _skillsByIndustry = const {};

  // name -> id, populated from the live fetch (empty offline).
  Map<String, String> _industryIds = const {};
  Map<String, String> _countryIds = const {};
  Map<String, String> _skillIds = const {};
  Map<String, String> _professionIds = const {};
  // country name -> E.164 dial code (e.g. "+62"). Seeded with offline fallbacks,
  // replaced by the full live map on fetch.
  Map<String, String> _countryPhone = _fallbackCountryPhone;

  /// Top-level industry names, falling back to a built-in list offline.
  List<String> get industries => _industries;

  /// Country names, falling back to a built-in list offline.
  List<String> get countries => _countries;

  /// Skill names, falling back to a built-in list offline.
  List<String> get skills => _skills;

  /// Skills to suggest for a given industry: the industry's own skills plus the
  /// always-available general (industry-less) skills. With no industry — or
  /// offline / an unknown id — it returns just the general skills.
  List<String> skillsForIndustry(String? industryId) =>
      suggestFor(_generalSkills, _skillsByIndustry, industryId);

  /// Pure suggestion logic (testable): [industryId]'s skills followed by the
  /// general skills, or just general when the industry is null/unknown.
  @visibleForTesting
  static List<String> suggestFor(
    List<String> general,
    Map<String, List<String>> byIndustry,
    String? industryId,
  ) {
    if (industryId == null || industryId.isEmpty) return general;
    final specific = byIndustry[industryId];
    if (specific == null || specific.isEmpty) return general;
    return [...specific, ...general];
  }

  /// Pure grouping (testable): split skills into general (no industry) and a
  /// map of industry id -> skill names.
  @visibleForTesting
  static ({List<String> general, Map<String, List<String>> byIndustry})
  groupSkills(List<Skill> skills) {
    final general = <String>[];
    final byIndustry = <String, List<String>>{};
    for (final s in skills) {
      if (s.name.isEmpty) continue;
      final iid = s.industryId;
      if (iid == null || iid.isEmpty) {
        general.add(s.name);
      } else {
        (byIndustry[iid] ??= <String>[]).add(s.name);
      }
    }
    return (general: general, byIndustry: byIndustry);
  }

  /// Profession names, falling back to a built-in list offline.
  List<String> get professions => _professions;

  /// The master-data id for a selected [name], or null if it's a custom entry
  /// (free-text) or the live data hasn't loaded yet.
  String? industryId(String name) => _industryIds[name];
  String? countryId(String name) => _countryIds[name];
  String? skillId(String name) => _skillIds[name];
  String? professionId(String name) => _professionIds[name];

  /// The E.164 dial code for a country name (e.g. "+62"), or null.
  String? countryPhoneCode(String name) => _countryPhone[name];

  /// (name, dial) pairs for countries that have a dial code — feeds the phone
  /// country-code picker. Ordered like [countries] (name asc from the backend).
  List<({String name, String dial})> get phoneCountries => [
    for (final n in _countries)
      if (_countryPhone[n] != null) (name: n, dial: _countryPhone[n]!),
  ];

  bool _loaded = false;
  Future<void>? _inFlight;

  /// Fetch the live lists once. Safe to call repeatedly: single-flight, and a
  /// (partial) success is cached. Never throws — on failure the fallback stays
  /// and a later call may retry.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    // Start all requests before awaiting so they run concurrently; each
    // resolves to [] on its own failure (so one failing doesn't sink the others
    // or surface as an unhandled async error).
    final industriesF = _safe(_api.fetchIndustries);
    final countriesF = _safe(_api.fetchCountries);
    final skillsF = _safe(_api.fetchSkills);
    final professionsF = _safe(_api.fetchProfessions);
    final industries = await industriesF;
    final countries = await countriesF;
    final skills = await skillsF;
    final professions = await professionsF;

    // Only replace a list when the backend actually returned data; an empty
    // response keeps the fallback so the pickers are never empty.
    var changed = false;

    if (industries.isNotEmpty) {
      _industries = [for (final i in industries) i.name];
      _industryIds = _idMap(industries, (i) => i.name, (i) => i.id);
      changed = true;
    }
    if (countries.isNotEmpty) {
      _countries = [for (final c in countries) c.name];
      _countryIds = _idMap(countries, (c) => c.name, (c) => c.id);
      _countryPhone = {
        for (final c in countries)
          if (c.name.isNotEmpty && (c.phoneCode?.isNotEmpty ?? false))
            c.name: c.phoneCode!,
      };
      changed = true;
    }
    if (skills.isNotEmpty) {
      _skills = [for (final s in skills) s.name];
      _skillIds = _idMap(skills, (s) => s.name, (s) => s.id);
      final grouped = groupSkills(skills);
      _generalSkills = grouped.general;
      _skillsByIndustry = grouped.byIndustry;
      changed = true;
    }
    if (professions.isNotEmpty) {
      _professions = [for (final p in professions) p.name];
      _professionIds = _idMap(professions, (p) => p.name, (p) => p.id);
      changed = true;
    }

    // Cache only once something loaded; a total failure stays retryable.
    if (changed) {
      _loaded = true;
      notifyListeners();
    }
  }

  static Map<String, String> _idMap<T>(
    List<T> rows,
    String Function(T) name,
    String Function(T) id,
  ) => {
    for (final r in rows)
      if (name(r).isNotEmpty && id(r).isNotEmpty) name(r): id(r),
  };

  Future<List<T>> _safe<T>(Future<List<T>> Function() fetch) async {
    try {
      return await fetch();
    } catch (_) {
      return <T>[];
    }
  }
}
