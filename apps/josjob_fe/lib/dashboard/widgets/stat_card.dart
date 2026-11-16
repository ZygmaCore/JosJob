part of '../dashboard_page.dart';

// =========================================================================
// A single KPI card: icon tile, big tabular value, label, and a tiny delta.
// =========================================================================
class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard(this.data);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            data.value,
            style: _tabular(
              GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
          ),
          const SizedBox(height: 8),
          Text(
            data.delta,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.iconGreen,
            ),
          ),
        ],
      ),
    );
  }
}
