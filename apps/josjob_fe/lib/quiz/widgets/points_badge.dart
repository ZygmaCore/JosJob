part of '../quiz_page.dart';

/// The gamified "points" chip (gold/orange accent). Used for the running score
/// and for the "+120 pts" earned on a correct live answer.
class _PointsBadge extends StatelessWidget {
  final int points;
  final bool signed; // show a leading "+"
  final bool big;
  const _PointsBadge(this.points, {this.signed = false, this.big = false});

  @override
  Widget build(BuildContext context) {
    final text = '${signed && points >= 0 ? '+' : ''}${_fmtPts(points)} pts';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 16 : 11,
        vertical: big ? 9 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.tintOrange,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: big ? 20 : 15, color: AppColors.iconOrange),
          const SizedBox(width: 5),
          Text(
            text,
            style: _tabular(
              GoogleFonts.poppins(
                fontSize: big ? 18 : 13,
                fontWeight: FontWeight.w700,
                color: AppColors.iconOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
