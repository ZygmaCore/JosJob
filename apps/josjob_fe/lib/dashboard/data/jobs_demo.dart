part of '../dashboard_page.dart';

// Jobs destinations use persisted API data. No sample applications are bundled.
const _jobsNav = <_NavDest>[
  _NavDest('Overview', Icons.dashboard_outlined),
  _NavDest('Vacancies', Icons.work_outline),
  _NavDest('Curriculum Vitae', Icons.badge_outlined),
  _NavDest('Applications', Icons.assignment_turned_in_outlined),
];
const _jobsData = _DashboardData(nav: _jobsNav, stats: []);
