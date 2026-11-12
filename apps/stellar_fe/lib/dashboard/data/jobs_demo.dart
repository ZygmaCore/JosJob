part of '../dashboard_page.dart';

// =========================================================================
// Sample data for the Jobs view of the dashboard (AI Job Placement). Stub
// content — nothing is fetched or persisted. Reuses the _DashboardData shell
// shape (nav + stats) so the Jobs view rides the same sidebar / top bar, and
// adds a couple of small job-specific fixtures consumed by _OverviewJobs.
// =========================================================================

/// A role matched to the candidate's profile.
class _JobMatch {
  final String title;
  final String company;
  final String location;
  final String type; // Full-time / Part-time / Contract
  final int matchPct; // 0..100
  final int seed; // picks the logo gradient (see _thumbGradient)
  const _JobMatch(
    this.title,
    this.company,
    this.location,
    this.type,
    this.matchPct,
    this.seed,
  );
}

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

final _jobsData = _DashboardData(
  nav: _jobsNav,
  stats: const [
    _StatData(
      label: 'Profile strength',
      value: '82%',
      delta: '+6% this week',
      icon: Icons.badge_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
    ),
    _StatData(
      label: 'New matches',
      value: '12',
      delta: '+4 today',
      icon: Icons.auto_awesome_outlined,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
    _StatData(
      label: 'Applications',
      value: '5',
      delta: '2 in review',
      icon: Icons.assignment_turned_in_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _StatData(
      label: 'Interviews',
      value: '2',
      delta: 'This week',
      icon: Icons.event_available_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
    ),
  ],
);

// Roles matched to the candidate's profile.
const _jobMatches = <_JobMatch>[
  _JobMatch(
    'Front Office Associate',
    'Hospitality Group',
    'Sydney, NSW',
    'Full-time',
    96,
    0,
  ),
  _JobMatch(
    'Site Supervisor',
    'BuildCorp',
    'Melbourne, VIC',
    'Full-time',
    92,
    1,
  ),
  _JobMatch(
    'Support Worker',
    'HealthFirst Care',
    'Brisbane, QLD',
    'Part-time',
    89,
    2,
  ),
  _JobMatch(
    'Guest Services Lead',
    'Coastline Resorts',
    'Gold Coast, QLD',
    'Full-time',
    85,
    3,
  ),
];

// The candidate's live applications (compact preview shown on the overview).
const _applications = <_Application>[
  _Application(
    'Front Office Associate',
    'Hospitality Group',
    _AppStage.interview,
    'Interview Thu',
  ),
  _Application(
    'Support Worker',
    'HealthFirst Care',
    _AppStage.screening,
    'In review',
  ),
  _Application(
    'Warehouse Coordinator',
    'Logistics Co',
    _AppStage.applied,
    'Applied 2d ago',
  ),
];

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

// =========================================================================
// CURRICULUM VITAE destination — the candidate's CV / profile. A worked
// sample persona so the CV reads as complete before real data is wired.
// =========================================================================

/// A role on the CV work-history timeline.
class _CvExperience {
  final String role;
  final String company;
  final String period;
  final String summary;
  const _CvExperience(this.role, this.company, this.period, this.summary);
}

/// A qualification on the CV education list.
class _CvEducation {
  final String qualification;
  final String institution;
  final String period;
  const _CvEducation(this.qualification, this.institution, this.period);
}

const _cvName = 'Jordan Blake';
const _cvHeadline = 'Front Office & Guest Services Professional';
const _cvLocation = 'Sydney, NSW';
const _cvEmail = 'jordan.blake@email.com';
const _cvPhone = '+61 400 000 000';
const _cvSummary =
    'Guest-focused hospitality professional with 5+ years across front '
    'office and customer care. Calm under pressure, quick with booking '
    'systems, and proud of a 4.8/5 guest-satisfaction record.';

const _cvExperience = <_CvExperience>[
  _CvExperience(
    'Front Office Associate',
    'Harbourview Hotel',
    '2023 — Present',
    'Manage check-in/out for a 180-room property, resolve guest issues, and '
        'train new front-desk staff on the booking system.',
  ),
  _CvExperience(
    'Guest Services Assistant',
    'City Central Inn',
    '2021 — 2023',
    'Handled reservations, concierge requests and billing; recognised twice '
        'for top monthly guest-satisfaction scores.',
  ),
  _CvExperience(
    'Customer Care Representative',
    'BrightLine Retail',
    '2019 — 2021',
    'Supported customers by phone and email, processing 40+ enquiries a day '
        'with a 95% first-contact resolution rate.',
  ),
];

const _cvEducation = <_CvEducation>[
  _CvEducation(
    'Certificate III in Hospitality',
    'Atveti Stellar',
    'Completed 2022',
  ),
  _CvEducation(
    'Certificate II in Customer Engagement',
    'TAFE NSW',
    'Completed 2019',
  ),
];

const _cvSkills = <String>[
  'Guest service',
  'Booking systems',
  'Conflict resolution',
  'Cash handling',
  'Rostering',
  'Team leadership',
  'CRM software',
  'Time management',
];

const _cvCerts = <_Certificate>[
  _Certificate('First Aid & CPR (HLTAID011)', 'St John', 'Valid to 2027'),
  _Certificate('Food Safety Supervisor', 'Atveti Stellar', 'Issued 2025'),
  _Certificate('Responsible Service of Alcohol', 'Service NSW', 'Issued 2024'),
];
