part of '../dashboard_page.dart';

// =========================================================================
// Hard-coded sample data + a role -> data selector. Bundled per view so the
// overview screens read a single object rather than reaching for globals.
// =========================================================================

class _DashboardData {
  final List<_NavDest> nav;
  final List<_StatData> stats;
  final List<_DashCourse> continueLearning;
  final List<_DashCourse> recommended;
  final List<_Mentor> coaching;
  final List<_Certificate> certificates;
  final List<_Learner> learners;
  final List<_DashCourse> offerings;
  final List<_ActivityItem> activity;
  final List<double> weeklyHours; // Mon..Sun
  final List<({String label, double value})> completionByCourse;
  const _DashboardData({
    required this.nav,
    required this.stats,
    this.continueLearning = const [],
    this.recommended = const [],
    this.coaching = const [],
    this.certificates = const [],
    this.learners = const [],
    this.offerings = const [],
    this.activity = const [],
    this.weeklyHours = const [],
    this.completionByCourse = const [],
  });
}

/// Selects the data bundle for a role. Null defaults to the individual view.
_DashboardData _dataFor(OnboardRole? role) =>
    isOrg(role) ? _orgData : _individualData;

// ---- Shared coaching schedule (both views) ------------------------------
const _sharedCoaching = <_Mentor>[
  _Mentor('Maya Chen', 'Interview confidence workshop', 'Today · 3:00 PM'),
  _Mentor('David Okoro', 'Resume review, live Q&A', 'Tomorrow · 10:00 AM'),
  _Mentor('Priya Nair', 'Excel for reporting', 'Thu · 1:30 PM'),
];

// ---- Certificates matched to the learner's profile (Target certificates) --
const _targetCertificates = <_TargetCert>[
  _TargetCert(
    'Certificate III in Hospitality',
    'Atveti Stellar',
    'Matches your Front Office applications',
  ),
  _TargetCert(
    'First Aid & CPR (HLTAID011)',
    'St John',
    'Required by 3 of your saved roles',
  ),
  _TargetCert(
    'Food Safety Supervisor',
    'Atveti Stellar',
    'Boosts your guest-services matches',
  ),
];

// ---- Bookable coaches (Live Coaching → Explore coaches) -------------------
const _exploreCoaches = <_Coach>[
  _Coach(
    'Maya Chen',
    'Interview coaching',
    'Ex-recruiter · 8 yrs',
    4.9,
    320,
    _CoachFocus.interview,
  ),
  _Coach(
    'David Okoro',
    'Resume & LinkedIn',
    'Career strategist',
    4.8,
    210,
    _CoachFocus.career,
  ),
  _Coach(
    'Priya Nair',
    'Data & reporting',
    'Analytics mentor',
    4.7,
    154,
    _CoachFocus.skills,
  ),
  _Coach(
    'Sam Rivera',
    'Confidence & comms',
    'Public-speaking coach',
    4.9,
    265,
    _CoachFocus.confidence,
  ),
  _Coach(
    'Aisha Khan',
    'Leadership & management',
    'Team-lead coach',
    4.9,
    342,
    _CoachFocus.leadership,
  ),
  _Coach(
    'Elena Rossi',
    'Career transitions',
    'Ex-HR director · 12 yrs',
    4.8,
    288,
    _CoachFocus.career,
  ),
  _Coach(
    'Marcus Bell',
    'Behavioural interviews',
    'STAR-method specialist',
    4.7,
    176,
    _CoachFocus.interview,
  ),
  _Coach(
    'Diego Santos',
    'Public speaking',
    'TEDx speaker coach',
    4.9,
    233,
    _CoachFocus.confidence,
  ),
  _Coach(
    'Nadia Hassan',
    'Technical interviews',
    'Ex-FAANG engineer',
    4.8,
    205,
    _CoachFocus.interview,
  ),
  _Coach(
    'Robert King',
    'First-time managers',
    'Leadership facilitator',
    4.7,
    167,
    _CoachFocus.leadership,
  ),
  _Coach(
    'Grace Lee',
    'Salary negotiation',
    'Compensation strategist',
    4.8,
    198,
    _CoachFocus.career,
  ),
  _Coach(
    'Tom Fischer',
    'Excel & spreadsheets',
    'Data-skills tutor',
    4.6,
    129,
    _CoachFocus.skills,
  ),
];

// =========================================================================
// INDIVIDUAL (worker / graduate)
// =========================================================================
const _individualNav = <_NavDest>[
  _NavDest('Overview', Icons.dashboard_outlined),
  _NavDest('Courses', Icons.menu_book_outlined),
  _NavDest('My Courses', Icons.play_lesson_outlined),
  _NavDest('Live Coaching', Icons.videocam_outlined),
  _NavDest('Certificates', Icons.workspace_premium_outlined),
];

final _individualData = _DashboardData(
  nav: _individualNav,
  stats: const [
    _StatData(
      label: 'In progress',
      value: '3',
      delta: '+1 this week',
      icon: Icons.menu_book_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
    ),
    _StatData(
      label: 'Hours learned',
      value: '42h',
      delta: '+6h this week',
      icon: Icons.schedule_outlined,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
    _StatData(
      label: 'Certificates',
      value: '2',
      delta: '+1 this month',
      icon: Icons.workspace_premium_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _StatData(
      label: 'Quiz progression',
      value: '75%',
      delta: '+8% this month',
      icon: Icons.trending_up,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
  ],
  continueLearning: const [
    _DashCourse(
      title: 'Customer Service Excellence',
      category: 'Hospitality',
      seed: 0,
      moduleCurrent: 4,
      moduleTotal: 8,
      progress: 0.5,
      quizId: 'customer-service',
    ),
    _DashCourse(
      title: 'Workplace Safety Essentials',
      category: 'Compliance',
      seed: 1,
      moduleCurrent: 5,
      moduleTotal: 6,
      progress: 0.82,
      quizId: 'workplace-safety',
    ),
    _DashCourse(
      title: 'Digital Literacy Foundations',
      category: 'IT',
      seed: 2,
      moduleCurrent: 2,
      moduleTotal: 5,
      progress: 0.35,
      quizId: 'digital-literacy',
    ),
  ],
  recommended: const [
    _DashCourse(
      title: 'Leadership & Team Management',
      category: 'Management',
      seed: 1,
      level: 'Intermediate',
      duration: '7h',
      rating: 4.8,
    ),
    _DashCourse(
      title: 'Financial Basics for Professionals',
      category: 'Finance',
      seed: 3,
      level: 'Beginner',
      duration: '6h',
      rating: 4.6,
    ),
    _DashCourse(
      title: 'First Aid & Emergency Response',
      category: 'Healthcare',
      seed: 2,
      level: 'Beginner',
      duration: '4h',
      rating: 4.9,
    ),
    _DashCourse(
      title: 'Effective Business Communication',
      category: 'Soft skills',
      seed: 0,
      level: 'Beginner',
      duration: '5h',
      rating: 4.7,
    ),
  ],
  coaching: _sharedCoaching,
  certificates: const [
    _Certificate(
      'Workplace Safety Level 1',
      'Atveti Stellar',
      'Issued Jun 2026',
    ),
    _Certificate(
      'Digital Literacy Foundations',
      'Atveti Stellar',
      'Issued Apr 2026',
    ),
  ],
  weeklyHours: const [1.2, 2.0, 1.5, 2.8, 2.2, 0.8, 1.6],
);

// =========================================================================
// ORG (employer / coordinator)
// =========================================================================
const _orgNav = <_NavDest>[
  _NavDest('Overview', Icons.dashboard_outlined),
  _NavDest('My Team', Icons.groups_outlined),
  _NavDest('Training', Icons.library_books_outlined),
  _NavDest('Live Coaching', Icons.videocam_outlined),
  _NavDest('Reports', Icons.insights_outlined),
];

final _orgData = _DashboardData(
  nav: _orgNav,
  stats: const [
    _StatData(
      label: 'Learners',
      value: '128',
      delta: '+12 this month',
      icon: Icons.groups_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
    ),
    _StatData(
      label: 'Active enrollments',
      value: '342',
      delta: '+28 this month',
      icon: Icons.menu_book_outlined,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
    _StatData(
      label: 'Avg. completion',
      value: '74%',
      delta: '+5% this month',
      icon: Icons.insights_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _StatData(
      label: 'Training offerings',
      value: '12',
      delta: '+2 this quarter',
      icon: Icons.library_books_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
    ),
  ],
  learners: const [
    _Learner('Ana Rivera', 'Front Office', 0.82, _LearnerStatus.onTrack),
    _Learner('Ben Costa', 'Warehouse', 0.41, _LearnerStatus.behind),
    _Learner('Chloe Kim', 'Finance', 1.0, _LearnerStatus.completed),
    _Learner('Diego Santos', 'Operations', 0.66, _LearnerStatus.onTrack),
    _Learner('Ella Novak', 'Customer Care', 0.28, _LearnerStatus.behind),
  ],
  offerings: const [
    _DashCourse(
      title: 'Workplace Safety Essentials',
      category: 'Compliance',
      seed: 1,
      progress: 0.78,
      enrolled: 64,
    ),
    _DashCourse(
      title: 'Customer Service Excellence',
      category: 'Hospitality',
      seed: 0,
      progress: 0.62,
      enrolled: 48,
    ),
    _DashCourse(
      title: 'Digital Literacy Foundations',
      category: 'IT',
      seed: 2,
      progress: 0.55,
      enrolled: 39,
    ),
    _DashCourse(
      title: 'Leadership & Team Management',
      category: 'Management',
      seed: 3,
      progress: 0.44,
      enrolled: 21,
    ),
  ],
  coaching: _sharedCoaching,
  activity: const [
    _ActivityItem(
      Icons.workspace_premium_outlined,
      AppColors.tintGreen,
      AppColors.iconGreen,
      'Chloe Kim completed "Excel Basics"',
      '12m ago',
    ),
    _ActivityItem(
      Icons.person_add_alt_1_outlined,
      AppColors.tintBlue,
      AppColors.iconBlue,
      'Diego Santos joined your workspace',
      '1h ago',
    ),
    _ActivityItem(
      Icons.play_circle_outline,
      AppColors.tintBlue,
      AppColors.iconBlue,
      'Ana Rivera started "Customer Service Excellence"',
      '3h ago',
    ),
    _ActivityItem(
      Icons.flag_outlined,
      AppColors.tintOrange,
      AppColors.iconOrange,
      'Ella Novak fell behind on "Workplace Safety"',
      'Yesterday',
    ),
  ],
  completionByCourse: const [
    (label: 'Safety Essentials', value: 0.78),
    (label: 'Customer Service', value: 0.62),
    (label: 'Digital Literacy', value: 0.55),
    (label: 'Leadership', value: 0.44),
  ],
);

// =========================================================================
// ORG destination data (superset fixtures for the My Team / Training /
// Reports screens, distinct from the trimmed previews on the overview).
// =========================================================================

// Full team roster for the "My Team" destination.
const _teamRoster = <_Learner>[
  _Learner(
    'Ana Rivera',
    'Front Office · 4 courses',
    0.82,
    _LearnerStatus.onTrack,
  ),
  _Learner('Ben Costa', 'Warehouse · 2 courses', 0.41, _LearnerStatus.behind),
  _Learner('Chloe Kim', 'Finance · 5 courses', 1.0, _LearnerStatus.completed),
  _Learner(
    'Diego Santos',
    'Operations · 3 courses',
    0.66,
    _LearnerStatus.onTrack,
  ),
  _Learner(
    'Ella Novak',
    'Customer Care · 2 courses',
    0.28,
    _LearnerStatus.behind,
  ),
  _Learner(
    'Farid Ahmed',
    'Logistics · 4 courses',
    0.91,
    _LearnerStatus.onTrack,
  ),
  _Learner(
    'Grace Lee',
    'Hospitality · 6 courses',
    1.0,
    _LearnerStatus.completed,
  ),
  _Learner(
    'Hana Suzuki',
    'IT Support · 3 courses',
    0.53,
    _LearnerStatus.onTrack,
  ),
];

// Full training catalog for the "Training" destination.
const _trainingCatalog = <_DashCourse>[
  _DashCourse(
    title: 'Workplace Safety Essentials',
    category: 'Compliance',
    seed: 1,
    progress: 0.78,
    enrolled: 64,
  ),
  _DashCourse(
    title: 'Customer Service Excellence',
    category: 'Hospitality',
    seed: 0,
    progress: 0.62,
    enrolled: 48,
  ),
  _DashCourse(
    title: 'Digital Literacy Foundations',
    category: 'IT',
    seed: 2,
    progress: 0.55,
    enrolled: 39,
  ),
  _DashCourse(
    title: 'Leadership & Team Management',
    category: 'Management',
    seed: 3,
    progress: 0.44,
    enrolled: 21,
  ),
  _DashCourse(
    title: 'First Aid & Emergency Response',
    category: 'Healthcare',
    seed: 2,
    progress: 0.71,
    enrolled: 33,
  ),
  _DashCourse(
    title: 'Effective Business Communication',
    category: 'Soft skills',
    seed: 0,
    progress: 0.58,
    enrolled: 27,
  ),
];

// Report KPI tiles for the "Reports" destination.
const _reportStats = <_StatData>[
  _StatData(
    label: 'Completion rate',
    value: '74%',
    delta: '+5% this month',
    icon: Icons.insights_outlined,
    tint: AppColors.tintGreen,
    iconColor: AppColors.iconGreen,
  ),
  _StatData(
    label: 'Active learners',
    value: '112',
    delta: '+9 this month',
    icon: Icons.groups_outlined,
    tint: AppColors.tintBlue,
    iconColor: AppColors.iconBlue,
  ),
  _StatData(
    label: 'Hours delivered',
    value: '1,240h',
    delta: '+180h this month',
    icon: Icons.schedule_outlined,
    tint: AppColors.tintOrange,
    iconColor: AppColors.iconOrange,
  ),
  _StatData(
    label: 'Certificates issued',
    value: '58',
    delta: '+7 this month',
    icon: Icons.workspace_premium_outlined,
    tint: AppColors.tintBlue,
    iconColor: AppColors.iconBlue,
  ),
];

// Monthly new-enrollment volume for the Reports bar chart (Feb..Jul).
const _reportEnrollments = <double>[38, 46, 41, 58, 52, 64];
const _reportMonths = <String>['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
