part of '../landing_page_ascent.dart';

class _RankingPreview extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback onUpload;
  const _RankingPreview({required this.onBrowse, required this.onUpload});

  @override
  Widget build(BuildContext context) => _Section(
    color: AppColors.paper2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow('A search with context'),
                  const SizedBox(height: 12),
                  _Title('See what a better fit can look like'),
                  const SizedBox(height: 8),
                  Text(
                    'JosJob is being built to connect job requirements with skills and learning.',
                    style: _lead(context),
                  ),
                ],
              ),
            ),
            if (_zig(context))
              TextButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('Explore jobs'),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cotton,
            border: Border.all(color: AppColors.rule),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.rule)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_outline,
                      color: AppColors.landingInk,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Opportunity preview',
                        style: TextStyle(
                          fontFamily: 'General Sans',
                          color: AppColors.landingInk,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Illustrative',
                        style: TextStyle(
                          fontFamily: 'General Sans',
                          color: AppColors.landingInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxWidth < 620;
                    final rows = [
                      (
                        '01',
                        'Role requirements',
                        'Compare your skills with what the role asks for.',
                        Icons.checklist_rtl,
                      ),
                      (
                        '02',
                        'Skill gap',
                        'See which requirements may need more practice.',
                        Icons.track_changes_outlined,
                      ),
                      (
                        '03',
                        'Learning path',
                        'Explore related courses available on the platform.',
                        Icons.menu_book_outlined,
                      ),
                    ];
                    return compact
                        ? Column(
                            children: [
                              for (final row in rows)
                                _PreviewRow(row: row, compact: true),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < rows.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i == rows.length - 1 ? 0 : 12,
                                    ),
                                    child: _PreviewRow(
                                      row: rows[i],
                                      compact: false,
                                    ),
                                  ),
                                ),
                            ],
                          );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.rule)),
                ),
                child: Text(
                  'Preview only. Live listings and personalized match scores are not available here yet.',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_zig(context)) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: const Text('Explore jobs'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Create an account to get started'),
          ),
        ),
      ],
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  final (String, String, String, IconData) row;
  final bool compact;
  const _PreviewRow({required this.row, required this.compact});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: compact ? 10 : 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cotton,
      border: Border.all(color: AppColors.rule),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.$1,
          style: TextStyle(
            fontFamily: 'Geist Mono',
            color: AppColors.ink2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          row.$4,
          size: 19,
          color: row.$2 == 'Skill gap'
              ? AppColors.landingInk
              : AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: row.$2 == 'Skill gap'
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                    : EdgeInsets.zero,
                decoration: row.$2 == 'Skill gap'
                    ? BoxDecoration(
                        color: AppColors.amberGap,
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  row.$2,
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    color: AppColors.landingInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                row.$3,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
