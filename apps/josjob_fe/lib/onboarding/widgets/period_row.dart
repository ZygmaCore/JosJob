part of '../onboarding_page.dart';

// From / To month-year pair. The host clears these by rebuilding the draft
// sub-form under a fresh key after "Add".
class _PeriodRow extends StatelessWidget {
  final _MonthYear? from;
  final _MonthYear? to;
  final ValueChanged<_MonthYear?> onFrom;
  final ValueChanged<_MonthYear?> onTo;
  const _PeriodRow({
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthYearField(label: 'From', value: from, onChanged: onFrom),
        const SizedBox(height: 14),
        _MonthYearField(
          label: 'To (leave empty if current)',
          value: to,
          onChanged: onTo,
        ),
      ],
    );
  }
}
