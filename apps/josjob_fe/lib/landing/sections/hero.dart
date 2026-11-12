part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Hero / Basecamp
// -------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onHowItWorks;
  const _Hero({required this.onCta, required this.onHowItWorks});

  @override
  Widget build(BuildContext context) {
    final desktop = _zig(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.6),
          radius: 1.2,
          colors: [AppColors.tintBlue, AppColors.bg],
          stops: [0.0, 1.0],
        ),
      ),
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.only(
            top: desktop ? 64 : 36,
            bottom: desktop ? 40 : 24,
          ),
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _HeroCopy(
                        onCta: onCta,
                        onHowItWorks: onHowItWorks,
                      ),
                    ),
                    const SizedBox(width: 40),
                    const Expanded(flex: 5, child: _Basecamp()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: _ReadinessGauge(
                        value: _readyTarget,
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _HeroCopy(onCta: onCta, onHowItWorks: onHowItWorks),
                  ],
                ),
        ),
      ),
    );
  }
}
