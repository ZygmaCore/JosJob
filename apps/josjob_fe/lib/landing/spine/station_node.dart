part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Station node — scroll-progress driven (upcoming · reached · current).
// -------------------------------------------------------------------------
class _StationNode extends StatelessWidget {
  final int index;
  final ValueNotifier<double> fraction;
  final double size;
  const _StationNode({
    required this.index,
    required this.fraction,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ValueListenableBuilder<double>(
        valueListenable: fraction,
        builder: (context, f, _) {
          final active = (f * _milestoneCount).floor().clamp(
            0,
            _milestoneCount - 1,
          );
          final reached = index <= active;
          final current = index == active;
          return _visual(context, reached, current);
        },
      ),
    );
  }

  Widget _visual(BuildContext context, bool reached, bool current) {
    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: reached
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.brandBlue],
              )
            : null,
        color: reached ? null : AppColors.surface,
        border: reached ? null : Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: (reached ? AppColors.brandBlue : AppColors.navy).withValues(
              alpha: reached ? 0.32 : 0.08,
            ),
            blurRadius: reached ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        '0${index + 1}',
        style: TextStyle(
          fontFamily: 'General Sans',
          fontSize: size * 0.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: reached ? Colors.white : AppColors.body,
        ),
      ),
    );
    return SizedBox(
      width: size + 22,
      height: size + 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo ring for the current station (static under reduced motion).
          AnimatedContainer(
            duration: _anim(context, 220),
            curve: Curves.easeOut,
            width: current ? size + 20 : size + 6,
            height: current ? size + 20 : size + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current
                  ? AppColors.brandBlue.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: current
                    ? AppColors.accent.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          core,
        ],
      ),
    );
  }
}
