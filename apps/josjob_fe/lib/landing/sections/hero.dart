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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.paper, AppColors.desk],
        ),
      ),
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.only(
            top: desktop ? 82 : 48,
            bottom: desktop ? 82 : 48,
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
