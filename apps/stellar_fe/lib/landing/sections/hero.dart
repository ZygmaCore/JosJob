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
        color: AppColors.desk,
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.7),
          radius: 1.35,
          colors: [AppColors.cotton, AppColors.desk, AppColors.paper3],
          stops: [0, .54, 1],
        ),
      ),
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.only(
            top: desktop ? 76 : 48,
            bottom: desktop ? 64 : 44,
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
                    _HeroCopy(onCta: onCta, onHowItWorks: onHowItWorks),
                    const SizedBox(height: 28),
                    const Center(child: _Basecamp()),
                  ],
                ),
        ),
      ),
    );
  }
}
