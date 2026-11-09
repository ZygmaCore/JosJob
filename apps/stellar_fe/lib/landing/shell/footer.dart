part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Footer (navy)
// -------------------------------------------------------------------------
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return ColoredBox(
      color: AppColors.navy,
      child: _Bounded(
        child: Padding(
          padding: const EdgeInsets.only(top: 56, bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: mobile ? 0 : 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Logo(color: Colors.white),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'One platform to build job-ready skills and get '
                            'matched with the employers who are hiring.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.onNavyDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 32 : 0),
                  const _FooterCol('Platform', [
                    'Online Learning',
                    'Live Coaching',
                    'Job Placement',
                    'Certifications',
                  ]),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 24 : 0),
                  const _FooterCol('Company', [
                    'About',
                    'Contact',
                    'Careers',
                    'Partners',
                  ]),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 24 : 0),
                  const _FooterCol('Get in touch', [
                    'hello@atveti.com',
                    '+61 439 158 812',
                  ]),
                ],
              ),
              const SizedBox(height: 40),
              Divider(color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 20),
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '© 2026 Atveti Stellar. All rights reserved.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.onNavyDim,
                    ),
                  ),
                  SizedBox(height: mobile ? 8 : 0),
                  Text(
                    'Online Learning & Job Placement',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.onNavyDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
