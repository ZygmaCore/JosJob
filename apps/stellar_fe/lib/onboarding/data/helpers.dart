part of '../onboarding_page.dart';

bool _compact(BuildContext c) => MediaQuery.sizeOf(c).width < 600;
bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

// "Jan 2020 – Present" style label for a period; empty when both ends are unset.
String _periodLabel(_MonthYear? from, _MonthYear? to) {
  if (from == null && to == null) return '';
  return '${from?.label ?? '—'} – ${to?.label ?? 'Present'}';
}

const Color _errorRed = Color(0xFFC62828);
