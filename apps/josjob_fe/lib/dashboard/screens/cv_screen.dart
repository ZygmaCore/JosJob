part of '../dashboard_page.dart';

// =========================================================================
// Curriculum Vitae destination (Jobs view): the candidate's CV — header
// contact card, professional summary, experience and education timelines,
// plus skills, certifications and a profile-strength nudge.
// =========================================================================
class _CvScreen extends StatelessWidget {
  const _CvScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          'Curriculum vitae',
          actionLabel: 'Download PDF',
          onAction: () => _demoAction(context),
        ),
        const SizedBox(height: 16),
        const _CvHeaderCard(),
        const SizedBox(height: 24),
        _TwoColumn(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CvSectionCard(
                title: 'Professional summary',
                child: Text(
                  _cvSummary,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppColors.body,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _CvSectionCard(
                title: 'Experience',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _cvExperience.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),
                      ],
                      _CvExperienceRow(_cvExperience[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _CvSectionCard(
                title: 'Education',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _cvEducation.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _CvEducationRow(_cvEducation[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CvSectionCard(
                title: 'Skills',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in _cvSkills) _CvSkillChip(skill),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _CvSectionCard(
                title: 'Certifications',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cert in _cvCerts) _CertificateRow(cert),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _ProfileStrengthCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// Contact / identity header: avatar, name, headline and contact meta, with an
// Edit action. Row on wide widths, stacked column on narrow.
class _CvHeaderCard extends StatelessWidget {
  const _CvHeaderCard();

  @override
  Widget build(BuildContext context) {
    final meta = Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _JobMeta(Icons.place_outlined, _cvLocation),
        _JobMeta(Icons.mail_outline, _cvEmail),
        _JobMeta(Icons.phone_outlined, _cvPhone),
      ],
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _cvName,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _cvHeadline,
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
        ),
        const SizedBox(height: 10),
        meta,
      ],
    );
    final editButton = _PillButton(
      label: 'Edit',
      variant: _PillVariant.tint,
      onPressed: () => _demoAction(context),
    );
    return _DashCard(
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 560) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Avatar(name: _cvName, size: 64),
                const SizedBox(width: 16),
                Expanded(child: identity),
                const SizedBox(width: 16),
                editButton,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Avatar(name: _cvName, size: 64),
              const SizedBox(height: 16),
              identity,
              const SizedBox(height: 16),
              editButton,
            ],
          );
        },
      ),
    );
  }
}

// A titled section container: a _DashCard with a heading above its content.
class _CvSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _CvSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// A single role on the experience timeline.
class _CvExperienceRow extends StatelessWidget {
  final _CvExperience exp;
  const _CvExperienceRow(this.exp);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exp.role,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${exp.company} · ${exp.period}',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exp.summary,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.body,
          ),
        ),
      ],
    );
  }
}

// A single qualification on the education list.
class _CvEducationRow extends StatelessWidget {
  final _CvEducation edu;
  const _CvEducationRow(this.edu);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          edu.qualification,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${edu.institution} · ${edu.period}',
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
        ),
      ],
    );
  }
}

// A rounded skill tag.
class _CvSkillChip extends StatelessWidget {
  final String skill;
  const _CvSkillChip(this.skill);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        skill,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}
