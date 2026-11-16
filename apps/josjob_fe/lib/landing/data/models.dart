part of '../landing_page_ascent.dart';

// =========================================================================
// Data — Josjob Workplace-Based Training
// =========================================================================
class _Item {
  final IconData icon;
  final String title;
  final String body;
  final List<String>?
  bullets; // when set, the card renders these as a bullet list
  final Color tint;
  final Color iconColor;
  const _Item(
    this.title,
    this.body, {
    this.icon = Icons.circle,
    this.bullets,
    this.tint = AppColors.tintBlue,
    this.iconColor = AppColors.iconBlue,
  });
}

class _Group {
  final String eyebrow;
  final String title;
  final List<_Item> items;
  const _Group(this.eyebrow, this.title, this.items);
}
