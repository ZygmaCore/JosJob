part of '../jobs_page.dart';

// =========================================================================
// Hard-coded sample roles for the board, spanning the platform's industries
// (hospitality, construction, healthcare). Nothing is fetched or persisted.
// =========================================================================
const _jobs = <_Job>[
  _Job(
    title: 'Front Office Associate',
    company: 'Hospitality Group',
    location: 'Sydney, NSW',
    type: 'Full-time',
    salary: '\$58k–\$64k',
    matchPct: 96,
    seed: 0,
    summary:
        'Be the first face guests meet — manage check-ins, bookings and '
        'front-desk service for a busy city hotel.',
    highlights: [
      'Handle guest check-in, check-out and billing',
      'Manage reservations across channels',
      'Coordinate with housekeeping and concierge',
    ],
    requirements: [
      'Customer Service Excellence certification',
      'Confident, friendly communication',
      'Availability for rotating shifts',
    ],
  ),
  _Job(
    title: 'Site Supervisor',
    company: 'BuildCorp',
    location: 'Melbourne, VIC',
    type: 'Full-time',
    salary: '\$85k–\$95k',
    matchPct: 92,
    seed: 1,
    summary:
        'Lead crews on commercial builds — keep sites safe, on schedule and '
        'to spec from groundwork to handover.',
    highlights: [
      'Supervise daily site operations and crews',
      'Own WHS compliance and toolbox talks',
      'Track progress against the build schedule',
    ],
    requirements: [
      'WHS / White Card certification',
      '3+ years on commercial sites',
      'Ability to read plans and coordinate trades',
    ],
  ),
  _Job(
    title: 'Support Worker',
    company: 'HealthFirst Care',
    location: 'Brisbane, QLD',
    type: 'Part-time',
    salary: '\$35–\$42 / hr',
    matchPct: 89,
    seed: 2,
    summary:
        'Provide compassionate day-to-day support that helps clients live '
        'independently at home and in the community.',
    highlights: [
      'Personal care and daily living support',
      'Community access and transport',
      'Keep clear, accurate care notes',
    ],
    requirements: [
      'First Aid & Emergency Response certification',
      'Reliable, empathetic and patient',
      'Driver licence and police check',
    ],
  ),
  _Job(
    title: 'Guest Services Lead',
    company: 'Coastline Resorts',
    location: 'Gold Coast, QLD',
    type: 'Full-time',
    salary: '\$66k–\$72k',
    matchPct: 85,
    seed: 3,
    summary:
        'Set the standard for guest experience across a coastal resort, '
        'mentoring a small front-of-house team.',
    highlights: [
      'Lead the front-of-house guest team',
      'Resolve escalations with care',
      'Coach new starters on service standards',
    ],
    requirements: [
      'Leadership & Team Management course',
      '2+ years in hospitality service',
      'Weekend and holiday availability',
    ],
  ),
  _Job(
    title: 'Warehouse Coordinator',
    company: 'Logistics Co',
    location: 'Perth, WA',
    type: 'Full-time',
    salary: '\$60k–\$68k',
    matchPct: 81,
    seed: 0,
    summary:
        'Keep goods moving — coordinate inbound and outbound stock, pick-pack '
        'accuracy and a safe, tidy floor.',
    highlights: [
      'Coordinate receiving and dispatch',
      'Maintain stock accuracy and records',
      'Uphold warehouse safety standards',
    ],
    requirements: [
      'Workplace Safety Essentials certification',
      'Forklift licence a plus',
      'Organised and detail-focused',
    ],
  ),
  _Job(
    title: 'Enrolled Nurse',
    company: 'HealthFirst Care',
    location: 'Adelaide, SA',
    type: 'Contract',
    salary: '\$40–\$48 / hr',
    matchPct: 78,
    seed: 2,
    summary:
        'Deliver clinical care alongside registered nurses across aged-care '
        'and community settings on a rolling contract.',
    highlights: [
      'Administer medication and treatments',
      'Monitor and document patient wellbeing',
      'Support registered nursing staff',
    ],
    requirements: [
      'Diploma of Nursing (enrolled)',
      'Current AHPRA registration',
      'Compassionate and dependable',
    ],
  ),
];
