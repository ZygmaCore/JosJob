part of '../dashboard_page.dart';

// =========================================================================
// One live-coaching session row: mentor avatar, name + topic, time, and a
// Join action. Used inside _UpNextCard.
// =========================================================================
class _CoachingTile extends StatelessWidget {
  final _Mentor mentor;
  const _CoachingTile(this.mentor);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(name: mentor.name, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mentor.name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mentor.topic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 13,
                    color: AppColors.body,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mentor.time,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.body,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: 'Join',
          onPressed: () => _liveClass(context),
          variant: _PillVariant.tint,
        ),
      ],
    );
  }
}
