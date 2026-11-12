part of '../explore_page.dart';

// =========================================================================
// Header — outcome-first title + search + catalog stats.
// =========================================================================
class _Header extends StatelessWidget {
  final int count;
  final int fields;
  final bool loading;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onClear;
  const _Header({
    required this.count,
    required this.fields,
    required this.loading,
    required this.controller,
    required this.query,
    required this.onQuery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.7),
          radius: 1.2,
          colors: [AppColors.tintBlue, AppColors.bg],
          stops: [0.0, 1.0],
        ),
      ),
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.only(
            top: _isMobile(context) ? 32 : 52,
            bottom: 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TagPill(
                loading
                    ? 'EXPLORE COURSES'
                    : 'EXPLORE COURSES · $count PROGRAMS',
                fg: AppColors.orange,
                bg: AppColors.tintOrange,
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  'Find the course that gets you certified.',
                  style: _h2s(context, color: AppColors.navy),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Browse the courses shared with you — study at your own pace, '
                  'join live classes, and work towards a certificate. Search by '
                  'title, field or category.',
                  style: _lead(context),
                ),
              ),
              const SizedBox(height: 24),
              _SearchField(
                controller: controller,
                query: query,
                onChanged: onQuery,
                onClear: onClear,
              ),
              if (!loading && count > 0) ...[
                const SizedBox(height: 14),
                _HeaderStats(count: count, fields: fields),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final int count;
  final int fields;
  const _HeaderStats({required this.count, required this.fields});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('$count', count == 1 ? 'course' : 'courses'),
      if (fields > 0) ('$fields', fields == 1 ? 'field' : 'fields'),
    ];
    return Wrap(
      spacing: 22,
      runSpacing: 8,
      children: [
        for (final (value, unit) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
