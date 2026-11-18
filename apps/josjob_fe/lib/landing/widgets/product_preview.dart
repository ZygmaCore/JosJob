part of '../landing_page_ascent.dart';

/// A small interactive tour, kept separate from the illustrative account data.
class _LandingProductPreview extends StatefulWidget {
  final ValueChanged<String> onOpen;
  const _LandingProductPreview({required this.onOpen});
  @override
  State<_LandingProductPreview> createState() => _LandingProductPreviewState();
}

class _LandingProductPreviewState extends State<_LandingProductPreview> {
  int _selected = 0;
  static const _labels = ['Jobs', 'Learning', 'Coaching'];
  static const _icons = [
    Icons.work_outline,
    Icons.auto_stories_outlined,
    Icons.forum_outlined,
  ];
  TextStyle _type(
    double size, {
    Color color = AppColors.navy,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.poppins(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.5,
  );
  Color get _accent => [
    AppColors.brandBlue,
    const Color(0xFF9B6221),
    AppColors.success,
  ][_selected];
  Color get _tint => [
    AppColors.tintBlue,
    AppColors.tintOrange,
    AppColors.tintGreen,
  ][_selected];
  Widget _tag(String label, {Color? tint, Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: tint ?? _tint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: _type(9, color: color ?? _accent, weight: FontWeight.w500),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('landing-product-tour'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE6F1FD), Color(0xFFF0F5FC)],
      ),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xFFDCE8F7)),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: 0,
          right: 0,
          width: 180,
          height: 160,
          child: ExcludeSemantics(
            child: CustomPaint(painter: _LandingDotPattern()),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(_isMobile(context) ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 17,
                      color: AppColors.brandBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ONE PLATFORM. YOUR NEXT MOVE.',
                        style: _type(
                          9,
                          color: AppColors.navy,
                          weight: FontWeight.w600,
                        ).copyWith(letterSpacing: 1),
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/branding/josjob-logo.svg',
                      width: 30,
                      height: 30,
                      excludeFromSemantics: true,
                    ),
                  ],
                ),
              ),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: .06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) => Row(
                          children: [
                            for (var index = 0; index < 3; index++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'landing-preview-${_labels[index].toLowerCase()}',
                                    ),
                                    selected: _selected == index,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _selected = index),
                                    label: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (c.maxWidth >= 330) ...[
                                            Icon(
                                              _icons[index],
                                              size: 14,
                                              color: _selected == index
                                                  ? AppColors.brandBlue
                                                  : AppColors.body,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            _labels[index],
                                            style: _type(
                                              11,
                                              color: _selected == index
                                                  ? AppColors.brandBlue
                                                  : AppColors.body,
                                              weight: _selected == index
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    side: BorderSide.none,
                                    backgroundColor: Colors.white,
                                    selectedColor: AppColors.tintBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(_isMobile(context) ? 17 : 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label:
                                'Illustrative ${_labels[_selected].toLowerCase()} preview. Sample content, not account data.',
                            image: true,
                            excludeSemantics: true,
                            child: AnimatedSize(
                              duration: _anim(context, 220),
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: _anim(context, 180),
                                child: ConstrainedBox(
                                  key: ValueKey(_selected),
                                  constraints: const BoxConstraints(
                                    minHeight: 300,
                                  ),
                                  child: switch (_selected) {
                                    0 => _jobs(),
                                    1 => _learning(),
                                    _ => _coaching(),
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: () => widget.onOpen(
                              ['/jobs', '/explore', '/coaching'][_selected],
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    [
                                      'Explore job opportunities',
                                      'Explore available courses',
                                      'Find your coach',
                                    ][_selected],
                                    style: _type(
                                      11,
                                      color: Colors.white,
                                      weight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 15),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.body,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Take a look around. Find your starting point.',
                      style: _type(9, color: AppColors.body),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: _type(
          24,
          weight: FontWeight.w600,
        ).copyWith(height: 1.2, letterSpacing: -.7),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: _type(11, color: AppColors.body)),
      const SizedBox(height: 18),
    ],
  );

  Widget _jobs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Opportunity looks\ngood on you.',
        'Explore a direction. Make it your own.',
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.work_outline, size: 20, color: _accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Junior software developer',
                        style: _type(11, weight: FontWeight.w600),
                      ),
                      Text(
                        'Sample employer',
                        style: _type(9, color: AppColors.body),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tag('Entry level'),
                _tag('Technology', tint: Colors.white, color: AppColors.body),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'One application. Every next step.',
        style: _type(11, weight: FontWeight.w500),
      ),
      const SizedBox(height: 13),
      Row(
        children: [
          for (final (index, label) in [
            'Applied',
            'Reviewing',
            'Interview',
            'Offer',
            'Hired',
          ].indexed)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 2, color: AppColors.border),
                      ),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 0
                              ? AppColors.brandBlue
                              : Colors.white,
                          border: Border.all(
                            color: index == 0
                                ? AppColors.brandBlue
                                : AppColors.rule2,
                          ),
                        ),
                        child: index == 0
                            ? const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Container(height: 2, color: AppColors.border),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style: _type(
                      7.5,
                      color: index == 0 ? AppColors.brandBlue : AppColors.body,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 15),
      _sampleLabel(),
    ],
  );

  Widget _learning() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Make room for\na new skill.',
        'Small steps can open new directions.',
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _tint,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined, size: 43, color: _accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn something useful.',
                    style: _type(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Courses. Classes. New possibilities.',
                    style: _type(10, color: AppColors.body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final (icon, label) in [
        (Icons.play_circle_outline, 'Explore available classes'),
        (Icons.school_outlined, 'Build practical foundations'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: _type(11, color: AppColors.body)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      _sampleLabel(),
    ],
  );

  Widget _coaching() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'A fresh perspective\nstarts with hello.',
        'Talk through what comes next.',
      ),
      _bubble('I’m not sure where to start.', outgoing: true),
      const SizedBox(height: 10),
      _bubble('Let’s work through your next step together.'),
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(Icons.event_available_outlined, size: 17, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free one-on-one appointments',
              style: _type(10, color: AppColors.body),
            ),
          ),
        ],
      ),
      const SizedBox(height: 15),
      _sampleLabel(),
    ],
  );
  Widget _bubble(String text, {bool outgoing = false}) => Align(
    alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.only(
        left: outgoing ? 24 : 0,
        right: outgoing ? 0 : 24,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: outgoing ? AppColors.brandBlue : AppColors.bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        text,
        style: _type(11, color: outgoing ? Colors.white : AppColors.navy),
      ),
    ),
  );
  Widget _sampleLabel() => Text(
    'ILLUSTRATIVE PREVIEW',
    style: _type(
      8,
      color: AppColors.body,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: 1.2),
  );
}

class _LandingDotPattern extends CustomPainter {
  const _LandingDotPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.brandBlue.withValues(alpha: .13);
    for (double x = 12; x < size.width; x += 15) {
      for (double y = 12; y < size.height; y += 15) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandingDotPattern oldDelegate) => false;
}
