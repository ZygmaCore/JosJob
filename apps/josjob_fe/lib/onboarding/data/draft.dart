part of '../onboarding_page.dart';

// =========================================================================
// Onboarding draft (de)serialization — converts the flow's collected answers
// to/from JSON so they can be stored via OnboardingDraftStore and restored on
// "Continue onboarding". Lives in the onboarding library so it can see the
// private step models.
// =========================================================================

Map<String, dynamic>? _monthYearToJson(_MonthYear? v) =>
    v == null ? null : {'month': v.month, 'year': v.year};

_MonthYear? _monthYearFromJson(dynamic v) {
  if (v is! Map) return null;
  final m = (v['month'] as num?)?.toInt();
  final y = (v['year'] as num?)?.toInt();
  return (m == null || y == null) ? null : _MonthYear(m, y);
}

Map<String, dynamic> _employmentToJson(_Employment e) => {
  'industry': e.industry,
  'name': e.name,
  'country': e.country,
  'internship': e.internship,
  'position': e.position,
  'from': _monthYearToJson(e.from),
  'to': _monthYearToJson(e.to),
};

_Employment _employmentFromJson(dynamic j) {
  final m = (j as Map);
  return _Employment(
    industry: (m['industry'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    country: (m['country'] ?? '').toString(),
    internship: m['internship'] == true,
    position: (m['position'] ?? '').toString(),
    from: _monthYearFromJson(m['from']),
    to: _monthYearFromJson(m['to']),
  );
}

Map<String, dynamic> _educationToJson(_Education e) => {
  'degree': e.degree,
  'name': e.name,
  'major': e.major,
  'country': e.country,
  'type': e.type,
  'from': _monthYearToJson(e.from),
  'to': _monthYearToJson(e.to),
};

_Education _educationFromJson(dynamic j) {
  final m = (j as Map);
  return _Education(
    degree: (m['degree'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    major: (m['major'] ?? '').toString(),
    country: (m['country'] ?? '').toString(),
    type: (m['type'] ?? '').toString(),
    from: _monthYearFromJson(m['from']),
    to: _monthYearFromJson(m['to']),
  );
}

Map<String, dynamic> _achievementToJson(_Achievement a) => {
  'type': a.type,
  'name': a.name,
  'country': a.country,
  'issuer': a.issuer,
  'from': _monthYearToJson(a.from),
  'to': _monthYearToJson(a.to),
};

_Achievement _achievementFromJson(dynamic j) {
  final m = (j as Map);
  return _Achievement(
    type: (m['type'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    country: (m['country'] ?? '').toString(),
    issuer: (m['issuer'] ?? '').toString(),
    from: _monthYearFromJson(m['from']),
    to: _monthYearFromJson(m['to']),
  );
}

// Safe casts for values coming back from decoded JSON.
List<String> _draftStrings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

List _draftList(dynamic v) => v is List ? v : const [];
