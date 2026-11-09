part of '../dashboard_page.dart';

// =========================================================================
// Rounded progress track + fill, with an optional right-aligned % label using
// tabular figures. Renders statically (no implicit animation) to respect
// reduced-motion by default.
// =========================================================================
class _ProgressBar extends StatelessWidget {
  final double value; // 0..1
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Container(height: 8, color: AppColors.border),
            Container(
              height: 8,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      value: '$pct percent',
      child: Row(
        children: [
          Expanded(child: bar),
          const SizedBox(width: 10),
          Text(
            '$pct%',
            style: _tabular(
              GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
