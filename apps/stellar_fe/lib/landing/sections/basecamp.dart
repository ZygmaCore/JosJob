part of '../landing_page_ascent.dart';

/// A compact product preview showing the job and skill journey.
class _Basecamp extends StatelessWidget {
  const _Basecamp();

  @override
  Widget build(BuildContext context) {
    final compact = !_zig(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 470 : 500),
        child: Container(
          padding: EdgeInsets.all(compact ? 20 : 28),
          decoration: BoxDecoration(
            color: AppColors.cotton,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.rule),
            boxShadow: [
              BoxShadow(
                color: AppColors.landingInk.withValues(alpha: .10),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/josjob_logo.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                    semanticLabel: 'JosJob logo',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your next opportunity',
                      style: TextStyle(
                        color: AppColors.landingInk,
                        fontFamily: 'General Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.more_horiz, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.sky,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.work_outline,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Junior product designer',
                                style: TextStyle(
                                  color: AppColors.landingInk,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Explore roles that fit your skills',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.bookmark_border, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Build skills as you go',
                      style: TextStyle(
                        color: AppColors.landingInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final label in ['Explore', 'Learn', 'Apply']) ...[
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: AppColors.ink2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (label != 'Apply') const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Illustrative preview · listings are coming soon',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
