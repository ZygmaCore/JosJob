part of '../dashboard_page.dart';

// =========================================================================
// "This week" learning-hours card wrapping the mini bar chart, with a total.
// =========================================================================
class _WeeklyActivityCard extends StatelessWidget {
  final List<double> hours;
  const _WeeklyActivityCard(this.hours);

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final total = hours.fold<double>(0, (a, b) => a + b);
    return _DashCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${total.toStringAsFixed(1)}h of learning',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tintGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.iconGreen,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MiniBarChart(values: hours, labels: _days),
        ],
      ),
    );
  }
}
