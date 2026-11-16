part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Footer (warm paper)
// -------------------------------------------------------------------------
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return ColoredBox(
      color: AppColors.paper2,
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
                        const _Logo(),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Explore opportunities, understand role requirements, '
                            'and connect your job search with learning.',
                            style: TextStyle(
                              fontFamily: 'General Sans',
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 32 : 0),
                  _FooterCol(
                    'Explore',
                    ['Jobs', 'Learning'],
                    onTap: (label) {
                      Navigator.of(
                        context,
                      ).pushNamed(label == 'Jobs' ? '/register' : '/explore');
                    },
                  ),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 24 : 0),
                  _FooterCol(
                    'Your next step',
                    ['Create an account', 'Sign in'],
                    onTap: (label) {
                      Navigator.of(
                        context,
                      ).pushNamed(label == 'Sign in' ? '/login' : '/register');
                    },
                  ),
                  SizedBox(width: mobile ? 0 : 40, height: mobile ? 24 : 0),
                ],
              ),
              const SizedBox(height: 40),
              Divider(color: AppColors.rule),
              const SizedBox(height: 20),
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '© 2026 JosJob. All rights reserved.',
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  SizedBox(height: mobile ? 8 : 0),
                  Text(
                    'Online Learning & Job Placement',
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 13,
                      color: AppColors.muted,
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
