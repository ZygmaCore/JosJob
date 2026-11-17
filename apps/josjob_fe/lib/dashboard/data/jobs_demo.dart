part of '../dashboard_page.dart';

// =========================================================================
// Shared Jobs navigation and legacy samples for the Applications screen.
// The Jobs overview reads JobsOverviewApi and does not consume these fixtures.
// =========================================================================

/// Where an application currently sits in the hiring pipeline.
enum _AppStage { applied, screening, interview, offer }

class _Application {
  final String role;
  final String company;
  final _AppStage stage;
  final String when;
  final int seed; // picks the logo gradient (see _thumbGradient)
  final String location;
  const _Application(
    this.role,
    this.company,
    this.stage,
    this.when, [
    this.seed = 0,
    this.location = '',
  ]);
}

// Jobs-view navigation destinations (index 0 is the built overview; the rest
// are placeholders, mirroring the learning nav).
const _jobsNav = <_NavDest>[
  _NavDest('Overview', Icons.dashboard_outlined),
  _NavDest('Vacancies', Icons.work_outline),
  _NavDest('Curriculum Vitae', Icons.badge_outlined),
  _NavDest('Applications', Icons.assignment_turned_in_outlined),
];

const _jobsData = _DashboardData(nav: _jobsNav, stats: []);

// The candidate's full application history for the Applications destination.
const _allApplications = <_Application>[
  _Application(
    'Front Office Associate',
    'Hospitality Group',
    _AppStage.interview,
    'Interview Thu · 2:00 PM',
    0,
    'Sydney, NSW',
  ),
  _Application(
    'Guest Services Lead',
    'Coastline Resorts',
    _AppStage.offer,
    'Offer received',
    3,
    'Gold Coast, QLD',
  ),
  _Application(
    'Support Worker',
    'HealthFirst Care',
    _AppStage.screening,
    'In review · applied 4d ago',
    2,
    'Brisbane, QLD',
  ),
  _Application(
    'Warehouse Coordinator',
    'Logistics Co',
    _AppStage.applied,
    'Applied 2d ago',
    1,
    'Perth, WA',
  ),
  _Application(
    'Customer Care Officer',
    'TeleConnect',
    _AppStage.applied,
    'Applied 6d ago',
    2,
    'Remote · AU',
  ),
  _Application(
    'Site Supervisor',
    'BuildCorp',
    _AppStage.screening,
    'In review · applied 1w ago',
    1,
    'Melbourne, VIC',
  ),
];
