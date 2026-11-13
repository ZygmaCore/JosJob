part of '../landing_page_ascent.dart';

/// Document inspired preview of the JosJob journey. It is illustrative and
/// does not claim a live match score or completed analysis.
class _Basecamp extends StatelessWidget {
  const _Basecamp();

  @override
  Widget build(BuildContext context) {
    final compact = !_zig(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 420 : 500),
        child: Container(
          padding: EdgeInsets.all(compact ? 18 : 26),
          decoration: BoxDecoration(
            color: AppColors.cotton,
            border: Border.all(color: AppColors.rule),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.landingInk.withValues(alpha: .10),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/josjob_logo.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                      semanticLabel: 'JosJob logo',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your next step',
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            color: AppColors.landingInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A connected job search',
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _PreviewStamp(),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(color: AppColors.rule),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Your CV',
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            color: AppColors.landingInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Profile document',
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _PreviewTrack(
                      label: 'Explore roles',
                      icon: Icons.work_outline,
                      active: true,
                    ),
                    const _PreviewTrack(
                      label: 'Build relevant skills',
                      icon: Icons.school_outlined,
                      active: false,
                    ),
                    const _PreviewTrack(
                      label: 'Apply with confidence',
                      icon: Icons.arrow_forward,
                      active: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Illustrative product preview',
                style: TextStyle(
                  fontFamily: 'General Sans',
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewStamp extends StatelessWidget {
  const _PreviewStamp();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.sky,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      'JosJob',
      style: TextStyle(
        fontFamily: 'General Sans',
        color: AppColors.landingInk,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PreviewTrack extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  const _PreviewTrack({
    required this.label,
    required this.icon,
    required this.active,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.sky,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? Colors.white : AppColors.landingInk,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'General Sans',
              color: AppColors.landingInk,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(
          active ? Icons.check_circle : Icons.chevron_right,
          size: 18,
          color: active ? AppColors.success : AppColors.muted,
        ),
      ],
    ),
  );
}
