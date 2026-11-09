part of '../dashboard_page.dart';

// =========================================================================
// Vacancies destination (Jobs view): the job board of open roles matched to
// the candidate's profile. Each card links to the role and an apply action.
// =========================================================================
class _VacanciesScreen extends StatelessWidget {
  const _VacanciesScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Open vacancies',
          actionLabel: 'Browse all',
          onAction: () => _browseJobs(context),
        ),
        const SizedBox(height: 6),
        Text(
          '${_vacancies.length} roles matched to your profile',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _VacancyFilterChips(),
        const SizedBox(height: 20),
        _VacancyGrid(_vacancies),
      ],
    );
  }
}

// Employment-type filter chips. First chip is selected; selection is hardcoded
// (no state) and every chip runs the demo action.
class _VacancyFilterChips extends StatelessWidget {
  static const _labels = [
    'All roles',
    'Full-time',
    'Part-time',
    'Contract',
    'Remote',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _labels.length; i++)
          _VacancyFilterChip(label: _labels[i], selected: i == 0),
      ],
    );
  }
}

class _VacancyFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _VacancyFilterChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _demoAction(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandBlue : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: AppColors.border, width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.body,
            ),
          ),
        ),
      ),
    );
  }
}

// Responsive grid of vacancy cards: 2-up when wide, else stacked.
class _VacancyGrid extends StatelessWidget {
  final List<_Vacancy> vacancies;
  const _VacancyGrid(this.vacancies);

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 2 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final v in vacancies)
              SizedBox(width: itemW, child: _VacancyCard(v)),
          ],
        );
      },
    );
  }
}

class _VacancyCard extends StatelessWidget {
  final _Vacancy v;
  const _VacancyCard(this.v);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _thumbGradient(v.seed),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _initials(v.company),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MatchBadge(v.matchPct),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _JobMeta(Icons.place_outlined, v.location),
              _JobMeta(Icons.work_outline, v.type),
              _JobMeta(Icons.payments_outlined, v.salary),
              _JobMeta(Icons.schedule_outlined, 'Posted ${v.posted}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in v.tags) _VacancyTag(tag)],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  label: 'View role',
                  icon: Icons.arrow_forward,
                  variant: _PillVariant.tint,
                  onPressed: () => _browseJobs(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PillButton(
                  label: 'Apply',
                  variant: _PillVariant.filled,
                  onPressed: () => _demoAction(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VacancyTag extends StatelessWidget {
  final String label;
  const _VacancyTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}
