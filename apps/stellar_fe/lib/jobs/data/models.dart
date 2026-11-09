part of '../jobs_page.dart';

// =========================================================================
// Sample-data model for a job posting. Plain and immutable — a hand-authored
// fixture, not a fetched entity.
// =========================================================================
class _Job {
  final String title;
  final String company;
  final String location;
  final String type; // Full-time / Part-time / Contract
  final String salary;
  final int matchPct; // 0..100
  final int seed; // picks the logo gradient (see _logoGradient)
  final String summary;
  final List<String> highlights;
  final List<String> requirements;
  const _Job({
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.salary,
    required this.matchPct,
    required this.seed,
    required this.summary,
    required this.highlights,
    required this.requirements,
  });
}
