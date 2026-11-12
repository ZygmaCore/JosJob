part of '../landing_page_ascent.dart';

class _PartnersSection extends StatelessWidget {
  const _PartnersSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: AppColors.bg,
      child: Column(
        children: [
          Text(
            'ACCREDITED & TRUSTED BY',
            style: TextStyle(
              fontFamily: 'General Sans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final p in _partners)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: AppColors.body,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p,
                        style: TextStyle(
                          fontFamily: 'General Sans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
