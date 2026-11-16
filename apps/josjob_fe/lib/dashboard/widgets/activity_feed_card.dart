part of '../dashboard_page.dart';

// =========================================================================
// Recent org activity feed — small icon tile, text, and a relative time.
// =========================================================================
class _ActivityFeedCard extends StatelessWidget {
  final List<_ActivityItem> items;
  const _ActivityFeedCard(this.items);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent activity',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _ActivityRow(items[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityRow(this.item);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: item.tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.text,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.time,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.body),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
