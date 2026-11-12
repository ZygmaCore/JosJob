part of '../landing_page_ascent.dart';

class _MissionBand extends StatelessWidget {
  const _MissionBand();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(
            'Our approach',
            color: Colors.white,
            tint: Color(0x22FFFFFF),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Text(
              '"We turn your skills into your next role — helping you learn '
              'what matters, earn the certifications that count, and get '
              'matched with the employers who are hiring."',
              style: GoogleFonts.poppins(
                fontSize: _isMobile(context) ? 20 : 30,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brandBlue,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The JosJob team',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Online Learning & Job Placement',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
