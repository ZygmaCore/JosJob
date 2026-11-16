part of '../explore_page.dart';

// =========================================================================
// Domain model — the course as the backend catalog actually stores it, plus
// the (single) sort control. Industry is a free-form name string from the
// backend master data, not a fixed enum; its visual language is resolved by
// name in data.dart.
// =========================================================================

enum _SortBy { az, za, mostClasses }

extension on _SortBy {
  String get label => switch (this) {
    _SortBy.az => 'Name (A–Z)',
    _SortBy.za => 'Name (Z–A)',
    _SortBy.mostClasses => 'Most classes',
  };
}

/// Per-industry visual language. Thumbnails are gradient blocks (no images):
/// a light [tint] diagonally into a saturated [gradEnd], with [icon] as both a
/// solid-chip glyph and a faint watermark. Resolved from an industry NAME.
class _IndustryVisual {
  final String short;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final Color gradEnd;
  const _IndustryVisual(
    this.short,
    this.icon,
    this.tint,
    this.iconColor,
    this.gradEnd,
  );
}

/// A catalog course, backed 1:1 by [CourseSummary] from the backend. Only the
/// fields the backend stores — no fabricated level/rating/duration.
class _Course {
  final String id;
  final String title;
  final String summary; // = description
  final List<String> industries; // industry names
  final String? section; // section (category) name
  final int classCount;
  final int? priceCents; // null/0 = free
  final String currency;

  const _Course({
    required this.id,
    required this.title,
    required this.summary,
    required this.industries,
    required this.section,
    required this.classCount,
    required this.currency,
    this.priceCents,
  });

  factory _Course.fromApi(CourseSummary c) => _Course(
    id: c.id,
    title: c.title,
    summary: c.description,
    industries: c.industries,
    section: c.sectionName,
    classCount: c.classCount,
    priceCents: c.priceCents,
    currency: c.currency,
  );

  /// The industry that drives the card's visual language (first listed).
  String? get primaryIndustry =>
      industries.isNotEmpty ? industries.first : null;

  bool get isFree => priceCents == null || priceCents! <= 0;

  /// e.g. "$49.00", or null when free.
  String? get priceLabel => isFree ? null : formatPrice(priceCents!, currency);
}
