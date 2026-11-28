part of '../onboarding_page.dart';

// -------------------------------------------------------------------------
// Sample content (placeholder — a real build would fetch these)
//
// Industries, countries, skills and professions now come from the backend via
// [MasterData]; the remaining lists below are still local sample content.
// -------------------------------------------------------------------------
const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Descending years for the month/year pickers (current year first).
final _years = <int>[for (var y = 2026; y >= 1967; y--) y];

const _degreeOptions = <String>[
  'High School',
  'Diploma',
  'Associate Degree',
  "Bachelor's Degree",
  "Master's Degree",
  'Doctorate (PhD)',
];

const _educationTypeOptions = <String>['General', 'Vocational'];

const _achievementTypeOptions = <String>[
  'Certification',
  'Course',
  'Training',
  'Workshop',
  'Bootcamp',
  'Seminar',
  'Other',
];
