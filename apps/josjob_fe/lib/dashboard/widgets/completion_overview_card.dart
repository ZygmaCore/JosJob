part of '../dashboard_page.dart';

// =========================================================================
// Completion-by-course overview: a horizontal bullet-style bar list (course
// label, progress track, % value). Reads cleanly on any width.
// =========================================================================
class _CompletionOverviewCard extends StatelessWidget {
  final List<({String label, double value})> data;
  const _CompletionOverviewCard(this.data);

  @override
  Widget build(BuildContext context) {
    final avg = data.isEmpty
        ? 0.0
        : data.fold<double>(0, (a, d) => a + d.value) / data.length;
    return _DashCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completion by course',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Average across offerings',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressRing(value: avg, size: 56),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              data[i].label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            _ProgressBar(value: data[i].value),
          ],
        ],
      ),
    );
  }
}
