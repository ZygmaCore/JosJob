part of '../explore_page.dart';

// -------------------------------------------------------------------------
// Industry visual language. Courses come from the backend; their industries
// are free-form names (master data). Known names get a hand-picked icon +
// colour; anything else falls back to a deterministic theme so every industry
// still renders a consistent, distinct gradient thumbnail.
// -------------------------------------------------------------------------

/// Deeper green for the healthcare thumbnail — no token exists for it; every
/// other colour comes from AppColors.
const _deepGreen = Color(0xFF2F8F59);

/// (tint, iconColor, gradEnd) triples reused across industries. The fallback
/// picks one of these by hashing the industry name.
const List<(Color, Color, Color)> _industryThemes = [
  (AppColors.tintBlue, AppColors.iconBlue, AppColors.heroBlue),
  (AppColors.tintOrange, AppColors.iconOrange, AppColors.orange),
  (AppColors.tintGreen, AppColors.iconGreen, _deepGreen),
  (AppColors.tintBlue, AppColors.navy, AppColors.navy),
  (AppColors.tintBlue, AppColors.accent, AppColors.accent),
];

/// Known industry names (as seeded on the backend) → (short label, icon, theme
/// index into [_industryThemes]).
const Map<String, (String, IconData, int)> _knownIndustries = {
  'Hospitality & Tourism': ('Hospitality', Icons.room_service_outlined, 0),
  'Construction & Trades': ('Construction', Icons.engineering_outlined, 1),
  'Healthcare': ('Healthcare', Icons.local_hospital_outlined, 2),
  'Manufacturing': ('Manufacturing', Icons.precision_manufacturing_outlined, 3),
  'Software & IT': ('Software & IT', Icons.memory_outlined, 4),
  'Finance': ('Finance', Icons.account_balance_outlined, 3),
  'Retail & Sales': ('Retail', Icons.storefront_outlined, 1),
  'Logistics & Transport': ('Logistics', Icons.local_shipping_outlined, 0),
};

/// The "All fields" / no-industry visual (used for the filter's default tile
/// and for a course that lists no industry).
const _IndustryVisual _generalVisual = _IndustryVisual(
  'All Fields',
  Icons.grid_view_rounded,
  AppColors.tintBlue,
  AppColors.brandBlue,
  AppColors.heroBlue,
);

/// Resolve the visual language for an industry [name]. Null/empty → the general
/// visual; a known name → its hand-picked treatment; anything else → a stable
/// theme chosen by hashing the name, with a generic icon.
_IndustryVisual _industryVisual(String? name) {
  final n = name?.trim() ?? '';
  if (n.isEmpty) return _generalVisual;

  final known = _knownIndustries[n];
  if (known != null) {
    final (short, icon, themeIdx) = known;
    final (tint, iconColor, gradEnd) = _industryThemes[themeIdx];
    return _IndustryVisual(short, icon, tint, iconColor, gradEnd);
  }

  // Deterministic fallback: pick a theme by the name's hash so the same
  // industry always renders identically across the catalog.
  final theme = _industryThemes[n.hashCode.abs() % _industryThemes.length];
  return _IndustryVisual(
    _shorten(n),
    Icons.workspace_premium_outlined,
    theme.$1,
    theme.$2,
    theme.$3,
  );
}

/// A compact label for a long industry name: the part before a "&"/"/"
/// separator (e.g. "Retail & Sales" → "Retail"), else the name itself.
String _shorten(String name) {
  final head = name.split(RegExp(r'\s*[&/]\s*')).first.trim();
  return head.isEmpty ? name : head;
}
