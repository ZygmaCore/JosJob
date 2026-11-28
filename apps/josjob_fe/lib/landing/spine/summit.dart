part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Summit — the payoff at the end of the journey.
// -------------------------------------------------------------------------
class _Summit extends StatelessWidget {
  final ValueNotifier<double> fraction;
  final bool desktop;
  const _Summit({required this.fraction, this.desktop = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fraction,
      builder: (context, f, _) {
        final reached = f >= 0.985;
        const title = 'Job-ready, skilled and certified';
        const sub = 'Every milestone complete — the summit of your journey.';
        if (desktop) {
          return Column(
            children: [
              _marker(reached),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: _lead(context).copyWith(fontSize: 14.5),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: Bp.railInset * 2,
              child: Align(
                alignment: Alignment.topCenter,
                child: _marker(reached),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(sub, style: _lead(context).copyWith(fontSize: 14)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _marker(bool reached) {
    final s = desktop ? 66.0 : 46.0;
    return SizedBox(
      width: s + 18,
      height: s + 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: reached ? s + 14 : s + 4,
            height: reached ? s + 14 : s + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandBlue.withValues(alpha: reached ? 0.14 : 0),
            ),
          ),
          Container(
            width: s,
            height: s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: reached
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.heroBlue, AppColors.brandBlue],
                    )
                  : null,
              color: reached ? null : AppColors.surface,
              border: reached
                  ? null
                  : Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (reached ? AppColors.brandBlue : AppColors.navy)
                      .withValues(alpha: reached ? 0.34 : 0.08),
                  blurRadius: reached ? 20 : 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: reached ? Colors.white : AppColors.body,
              size: s * 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
