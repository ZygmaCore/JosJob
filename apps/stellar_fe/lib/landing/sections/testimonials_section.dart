part of '../landing_page_ascent.dart';

class _TestimonialsSection extends StatefulWidget {
  const _TestimonialsSection();
  @override
  State<_TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<_TestimonialsSection> {
  int _i = 0;
  void _go(int d) => setState(
    () => _i = (_i + d + _testimonials.length) % _testimonials.length,
  );

  @override
  Widget build(BuildContext context) {
    final (quote, name, meta, tag) = _testimonials[_i];
    return _Section(
      color: AppColors.bg,
      child: Column(
        children: [
          _Title('Results that speak for themselves', center: true),
          const SizedBox(height: 12),
          Text(
            'Stories from people Atveti Stellar has trained and certified.',
            textAlign: TextAlign.center,
            style: _lead(context),
          ),
          const SizedBox(height: 36),
          AnimatedSwitcher(
            duration: _anim(context, 250),
            child: Container(
              key: ValueKey(_i),
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 860),
              padding: EdgeInsets.all(_isMobile(context) ? 26 : 44),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tintGreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppColors.iconGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tag,
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.iconGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    quote,
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: _isMobile(context) ? 19 : 25,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.landingInk,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.tintBlue,
                        child: Text(
                          name.characters.first,
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            color: AppColors.brandBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'General Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.landingInk,
                            ),
                          ),
                          Text(
                            meta,
                            style: TextStyle(
                              fontFamily: 'General Sans',
                              fontSize: 14,
                              color: AppColors.body,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arrow(Icons.chevron_left, 'Previous testimonial', () => _go(-1)),
              const SizedBox(width: 18),
              for (int j = 0; j < _testimonials.length; j++) ...[
                _dot(j == _i),
                if (j != _testimonials.length - 1) const SizedBox(width: 8),
              ],
              const SizedBox(width: 18),
              _arrow(Icons.chevron_right, 'Next testimonial', () => _go(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, String label, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        focusColor: AppColors.focus,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.body),
        ),
      ),
    ),
  );

  Widget _dot(bool active) => ExcludeSemantics(
    child: Container(
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.brandBlue : AppColors.border,
        borderRadius: BorderRadius.circular(100),
      ),
    ),
  );
}
