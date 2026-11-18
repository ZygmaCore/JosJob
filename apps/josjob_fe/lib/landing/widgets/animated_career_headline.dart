part of '../landing_page_ascent.dart';

/// The daisyUI text-rotate pattern rendered with the shared Flutter typography.
/// Only the word animates; its widest measurement reserves a stable line width.
class AnimatedCareerHeadline extends StatefulWidget {
  final TextStyle style;
  const AnimatedCareerHeadline({super.key, required this.style});
  @override
  State<AnimatedCareerHeadline> createState() => _AnimatedCareerHeadlineState();
}

class _AnimatedCareerHeadlineState extends State<AnimatedCareerHeadline>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _words = ['ambitions.', 'dreams.', 'ideas.', 'goals.', 'plans.'];
  static const _interval = Duration(milliseconds: 500);
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  Timer? _timer;
  int _index = 0, _previous = 0;
  bool _reduced = false, _visible = true, _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_reduced || !_visible || !_active) {
      _timer?.cancel();
      _timer = null;
      _motion.value = 1;
      return;
    }
    _timer ??= Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() {
        _previous = _index;
        _index = (_index + 1) % _words.length;
      });
      _motion.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final painters = [
        for (final word in _words)
          TextPainter(
            text: TextSpan(text: word, style: widget.style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout(),
      ];
      final width = math.min(
        constraints.maxWidth,
        painters.map((p) => p.width).reduce(math.max),
      );
      final height = painters.map((p) => p.height).reduce(math.max);
      final widths = painters.map((p) => p.width).toList();
      for (final painter in painters) {
        painter.dispose();
      }
      return Semantics(
        header: true,
        label: 'Big ambitions. Clear next steps.',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Big ', style: widget.style),
                SizedBox(
                  key: const ValueKey('career-word-frame'),
                  width: width,
                  height: height,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) {
                        final incoming = Curves.easeOutCubic.transform(
                          _motion.value,
                        );
                        final outgoing = Curves.easeInCubic.transform(
                          _motion.value,
                        );
                        // Stagger the fades so two strong words never overlap.
                        final fadeOut = const Interval(
                          0,
                          .45,
                          curve: Curves.easeOutCubic,
                        ).transform(_motion.value);
                        final fadeIn = const Interval(
                          .2,
                          1,
                          curve: Curves.easeOutCubic,
                        ).transform(_motion.value);
                        Widget word(
                          int index,
                          double opacity,
                          double offset,
                          double blur,
                        ) => Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(0, offset),
                            child: Opacity(
                              opacity: opacity,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: blur,
                                  sigmaY: blur,
                                ),
                                enabled: blur > 0.01,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _words[index],
                                    key: ValueKey(
                                      'career-word-${_words[index]}',
                                    ),
                                    style: widget.style,
                                    textScaler: scaler,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        return Stack(
                          children: [
                            if (_previous != _index && _motion.value < 1)
                              word(
                                _previous,
                                1 - fadeOut,
                                -height * .3 * outgoing,
                                2 * outgoing,
                              ),
                            word(
                              _index,
                              fadeIn,
                              height * .35 * (1 - incoming),
                              2.5 * (1 - incoming),
                            ),
                            Positioned(
                              left: 0,
                              bottom: 1,
                              width: math.min(
                                width,
                                ui.lerpDouble(
                                  widths[_previous],
                                  widths[_index],
                                  incoming,
                                )!,
                              ),
                              height: 2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.brandBlue.withValues(
                                    alpha: .32,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Clear next steps.',
              style: widget.style.copyWith(color: AppColors.brandBlue),
            ),
          ],
        ),
      );
    },
  );
}
