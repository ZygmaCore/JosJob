part of '../onboarding_page.dart';

// A month + year value used by the Employment / Education period pickers.
class _MonthYear {
  final int month; // 1..12
  final int year;
  const _MonthYear(this.month, this.year);
  String get label => '${_months[month - 1]} $year';
}

// One work-experience entry (Employment step).
class _Employment {
  final String industry;
  final String name; // company / employer
  final String country;
  final bool internship;
  final String position;
  final _MonthYear? from;
  final _MonthYear? to; // null => current
  const _Employment({
    required this.industry,
    required this.name,
    required this.country,
    required this.internship,
    required this.position,
    required this.from,
    required this.to,
  });
}

// One formal-education entry (Education step).
class _Education {
  final String degree; // Diploma / Bachelor's / …
  final String name;
  final String major; // field of study (jurusan)
  final String country;
  final String type; // General / Vocational
  final _MonthYear? from;
  final _MonthYear? to;
  const _Education({
    required this.degree,
    required this.name,
    required this.major,
    required this.country,
    required this.type,
    required this.from,
    required this.to,
  });
}

// One non-formal education / achievement entry (Education step).
class _Achievement {
  final String type; // Certification / Course / …
  final String name;
  final String country;
  final String issuer; // issued / held by
  final _MonthYear? from;
  final _MonthYear? to;
  const _Achievement({
    required this.type,
    required this.name,
    required this.country,
    required this.issuer,
    required this.from,
    required this.to,
  });
}
