part of '../explore_page.dart';

/// Fixed-height course card: a gradient thumbnail band (industry icon chip,
/// bookmark, optional section badge) over a body with the industry, title,
/// description and class count. Fixed height so cards align across a Wrap row.
class _CourseCard extends StatelessWidget {
  final _Course course;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  const _CourseCard({
    required this.course,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _industryVisual(course.primaryIndustry);
    return SizedBox(
      height: 356,
      child: _HoverLift(
        builder: (hover) => Semantics(
          button: true,
          label: '${course.title}, ${visual.short}',
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(20),
              focusColor: AppColors.focus,
              child: AnimatedContainer(
                duration: _anim(context, 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hover ? visual.iconColor : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardBand(
                      course: course,
                      visual: visual,
                      saved: saved,
                      onSave: onSave,
                    ),
                    Expanded(
                      child: _CardBody(
                        course: course,
                        visual: visual,
                        onOpen: onOpen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBand extends StatelessWidget {
  final _Course course;
  final _IndustryVisual visual;
  final bool saved;
  final VoidCallback onSave;
  const _CardBand({
    required this.course,
    required this.visual,
    required this.saved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      visual.tint,
                      visual.gradEnd.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -12,
              child: Icon(
                visual.icon,
                size: 104,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(visual.icon, color: visual.iconColor, size: 24),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              // A single accessible node: the IconButton's tooltip doubles as
              // its screen-reader label (no wrapping Semantics -> no double
              // announce).
              child: IconButton(
                onPressed: onSave,
                tooltip: saved ? 'Remove from saved' : 'Save course',
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  color: saved ? AppColors.brandBlue : AppColors.navy,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ),
            if (course.section != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Row(
                  children: [
                    Flexible(
                      child: _BandBadge(
                        icon: Icons.category_outlined,
                        label: course.section!,
                        bg: AppColors.surface,
                        fg: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BandBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  const _BandBadge({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final _Course course;
  final _IndustryVisual visual;
  final VoidCallback onOpen;
  const _CardBody({
    required this.course,
    required this.visual,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final extraIndustries = course.industries.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: _TagPill(
                  visual.short,
                  fg: visual.iconColor,
                  bg: visual.tint,
                ),
              ),
              if (extraIndustries > 0) ...[
                const SizedBox(width: 8),
                _TagPill(
                  '+$extraIndustries',
                  fg: AppColors.body,
                  bg: AppColors.border,
                ),
              ],
              const Spacer(),
              _TagPill(
                course.isFree ? 'Free' : course.priceLabel!,
                fg: course.isFree ? AppColors.iconGreen : AppColors.brandBlue,
                bg: course.isFree ? AppColors.tintGreen : AppColors.tintBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          if (course.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              course.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.body,
              ),
            ),
          ],
          const Spacer(),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cast_for_education_outlined,
                      size: 15,
                      color: AppColors.body,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        course.classCount == 0
                            ? 'No classes yet'
                            : '${course.classCount} '
                                  '${course.classCount == 1 ? 'class' : 'classes'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PillButton(
                'View course',
                kind: _BtnKind.dense,
                trailing: Icons.arrow_forward,
                onPressed: onOpen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
