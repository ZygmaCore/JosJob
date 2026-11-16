part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Brand panel (navy gradient) — desktop only
// -------------------------------------------------------------------------
class _BrandPanel extends StatelessWidget {
  final String headline;
  final String sub;
  final List<String> points;
  const _BrandPanel({
    required this.headline,
    required this.sub,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // End stop kept darker than brandBlue so onNavyDim secondary text
          // over the bottom of the panel keeps >=4.5:1 contrast (AA).
          colors: [AppColors.navy, Color(0xFF13396B), Color(0xFF1A5296)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandLogo(dark: false),
              const Spacer(),
              Text(
                headline,
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  sub,
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    height: 1.55,
                    color: AppColors.onNavyDim,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              for (final p in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p,
                          style: GoogleFonts.poppins(
                            fontSize: 15.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                'Various sectors · Live coaching · Recognised certifications',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onNavyDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
