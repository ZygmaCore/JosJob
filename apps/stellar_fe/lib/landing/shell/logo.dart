part of '../landing_page_ascent.dart';

class _Logo extends StatelessWidget {
  final Color color;
  const _Logo({this.color = AppColors.brandBlue});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Atveti Stellar home',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 26),
          const SizedBox(width: 8),
          Text(
            'Atveti Stellar',
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
