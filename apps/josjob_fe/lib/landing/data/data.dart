part of '../landing_page_ascent.dart';

const _navItems = ['Learn', 'Jobs', 'How it works'];

// The two products the platform brings together — folded into the landing as a
// dedicated band right below the hero (see sections/products_band.dart).
const _products = [
  _Item(
    'Learn',
    'Explore self-paced courses and classes available through the platform.',
    icon: Icons.school_outlined,
    bullets: [
      'Browse available courses',
      'Explore classes and learning materials',
      'Build skills at your own pace',
    ],
    tint: AppColors.paper2,
    iconColor: AppColors.landingInk,
  ),
  _Item(
    'Find work',
    'Explore opportunities and learn what employers are looking for.',
    icon: Icons.work_outline,
    bullets: [
      'Search by role, skill or company',
      'Review role requirements',
      'Connect skills with learning',
    ],
    tint: AppColors.cotton,
    iconColor: AppColors.primary,
  ),
];

// Milestone 01 — impact stats grounded in the delivery model.
const _stats = [
  (
    'Various',
    'sectors',
    'Learn in your field — hospitality, construction, healthcare and more.',
  ),
  ('24/7', 'access', 'Self-paced online learning portal, any time.'),
  (
    'Live',
    'coaching',
    'Live coaching anywhere, any place, via live streaming with qualified trainers.',
  ),
  (
    '100%',
    'compliance',
    'Earn the mandatory certifications and standards your role needs.',
  ),
];

// Milestone 02 · Blended Learning Approach
const _blended = _Group(
  'MILESTONE 02 · HOW YOU LEARN',
  'A blended learning approach',
  [
    _Item(
      'Online Learning Portal',
      'Self-paced modules with built-in assessments and quizzes, accessible 24/7 — with an AI teaching assistant on hand to answer your questions.',
      icon: Icons.laptop_mac_outlined,
    ),
    _Item(
      'Live Coaching',
      'Live coaching anywhere, any place — practical, hands-on sessions delivered by qualified trainers via live streaming.',
      icon: Icons.cast_for_education_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _Item(
      'Mentorship Programs',
      'Our flagship program pairs you one-on-one with seasoned industry specialists for real skill transfer and career-focused guidance.',
      icon: Icons.diversity_3_outlined,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
  ],
);

// Milestone 03 · Who the learning is for (target audience)
const _audience = _Group(
  'MILESTONE 03 · WHO IT\'S FOR',
  'Built for every kind of learner',
  [
    _Item(
      'Business Owners',
      'Upgrade your team\'s skills to stay relevant to the market and lift productivity.',
      icon: Icons.business_center_outlined,
      bullets: [
        'Upskill your workforce',
        'Stay market-relevant',
        'Boost productivity',
      ],
    ),
    _Item(
      'Vocational Coordinators',
      'Run industry-standard, skill-upgrading programs for your students.',
      icon: Icons.hub_outlined,
      bullets: [
        'Standards-aligned',
        'For your students',
        'Clear skill pathways',
      ],
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _Item(
      'Individual Workers',
      'Advance your own capabilities for career acceleration and new opportunities.',
      icon: Icons.engineering_outlined,
      bullets: [
        'Learn independently',
        'Accelerate your career',
        'New opportunities',
      ],
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
    _Item(
      'Students & Graduates',
      'Gain hands-on skills that bridge academic study and the real working world.',
      icon: Icons.school_outlined,
      bullets: ['Hands-on training', 'Theory to practice', 'Workforce-ready'],
    ),
  ],
);

// Milestone 04 · Compliance and Safety Training
const _compliance = _Group(
  'MILESTONE 04 · COMPLIANCE & SAFETY',
  'Compliance & safety training',
  [
    _Item(
      'Mandatory Certifications',
      'Training for required industry licenses, safety certifications and Language Literacy & Numeracy (LLN) certification.',
      icon: Icons.workspace_premium_outlined,
    ),
    _Item(
      'Quality Assurance',
      'Implementation of quality management systems and best practices.',
      icon: Icons.fact_check_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
    ),
    _Item(
      'Regulatory Compliance',
      'Meet local and international regulatory standards, industry compliance, and certification requirements.',
      icon: Icons.gavel_outlined,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
    ),
  ],
);

// Milestone 05 — how a program runs.
const _steps = [
  (
    '01',
    'Assess & plan',
    'We map your skill gaps and the certifications your role needs.',
  ),
  (
    '02',
    'Blended delivery',
    'Self-paced online modules with assessments and quizzes, paired with scheduled live coaching.',
  ),
  (
    '03',
    'Coaching & mentorship',
    'Qualified trainers coach you live; senior staff mentor you one-on-one.',
  ),
  (
    '04',
    'Certify & report',
    'You earn recognised certifications and a clear record of everything you complete.',
  ),
];

const _faqs = [
  (
    'How is the training delivered?',
    'A blend of a self-paced online portal with assessments and quizzes, live coaching by qualified trainers via live streaming, and mentorship pairing you with senior staff.',
  ),
  (
    'Which industries do you cover?',
    'Various sectors — including Hospitality & Tourism, Construction & Trades, and Healthcare Support — each with learning tailored to that field.',
  ),
  (
    'Do you handle compliance and certifications?',
    'Yes — mandatory certifications, language, literacy and numeracy (LLN), quality management, and local and international regulatory compliance.',
  ),
  (
    'Where does the live coaching happen?',
    'Anywhere. Live coaching is delivered by qualified trainers via live streaming, so you can join from any place, scheduled around your work.',
  ),
  (
    'How do you measure my progress?',
    'We track your module completion, assessments and quizzes, and certifications, with a clear record of everything you complete.',
  ),
];

// (quote, name, meta, tag)
const _testimonials = [
  (
    '"I hit the floor confident and compliant — the training got me job-ready fast."',
    'Priya M.',
    'Front Office · Hospitality',
    'Faster onboarding',
  ),
  (
    '"Live coaching meant zero downtime. I earned my WHS certification without leaving the site."',
    'Daniel K.',
    'Site Crew · Construction',
    'WHS certified',
  ),
  (
    '"The mentorship pairing transferred real skills fast, and my assessments have never gone better."',
    'Sarah L.',
    'Support Worker · Healthcare',
    'Quality assured',
  ),
];

const _partners = [
  'Trade Skills Australia',
  'WorkSafe',
  'Industry Skills Council',
  'RTO Accreditation',
  'Hospitality Institute',
  'Safety Standards Board',
];

const _moments = [
  'Live WHS coaching',
  'Hospitality floor training',
  'Healthcare facility session',
  'Mentorship pairing',
  'Compliance workshop',
  'Equipment operation training',
];

const int _milestoneCount = 5;
