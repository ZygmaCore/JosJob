part of '../landing_page_ascent.dart';

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'JosJob home',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/josjob_logo.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            semanticLabel: 'JosJob logo',
          ),
          const SizedBox(width: 8),
          Text(
            'JosJob',
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.landingInk,
            ),
          ),
        ],
      ),
    );
  }
}
