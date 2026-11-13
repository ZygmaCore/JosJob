part of '../auth_page.dart';

class _BrandLogo extends StatelessWidget {
  final bool dark; // dark=true renders brand-blue-on-light; false=white-on-navy
  const _BrandLogo({required this.dark});

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.brandBlue : Colors.white;
    return Semantics(
      label: 'JosJob',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 26),
          const SizedBox(width: 8),
          Text(
            'JosJob',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
