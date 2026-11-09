part of '../quiz_page.dart';

/// A single quiz in the hub catalog: a tinted tier icon, the title + subtitle,
/// a meta line (question count · time · pass rule), and a Start/Join action.
/// Full-width list item that lifts on hover.
class _QuizCard extends StatelessWidget {
  final QuizTier tier;
  final String title;
  final String subtitle;
  final String meta;
  final String cta;
  final VoidCallback onTap;
  const _QuizCard({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Semantics(
      button: true,
      label: '$title, $cta',
      child: _HoverLift(
        builder: (hover) => Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            focusColor: AppColors.focus,
            child: AnimatedContainer(
              duration: _anim(context, 160),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hover ? tier.accent : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: hover ? const [_cardShadow] : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tier.tint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(tier.icon, color: tier.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.body,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tier.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!mobile) ...[
                        Text(
                          cta,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: tier.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.arrow_forward, size: 18, color: tier.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
