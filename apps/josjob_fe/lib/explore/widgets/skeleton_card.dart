part of '../explore_page.dart';

/// A grid of skeleton cards shown during the simulated load — same fixed
/// height and grid as real cards, so the layout never jumps.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return const _ResponsiveGrid(
      children: [
        _SkeletonCard(),
        _SkeletonCard(),
        _SkeletonCard(),
        _SkeletonCard(),
        _SkeletonCard(),
        _SkeletonCard(),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shimmer only when motion is allowed; otherwise a static block.
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 356,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(height: 128, radiusTop: true),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(height: 20, width: 120),
                  const SizedBox(height: 14),
                  _block(height: 16, width: double.infinity),
                  const SizedBox(height: 8),
                  _block(height: 16, width: 180),
                  const SizedBox(height: 16),
                  _block(height: 34, width: double.infinity),
                  const SizedBox(height: 16),
                  _block(height: 14, width: 160),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block({
    required double height,
    double? width,
    bool radiusTop = false,
  }) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _reduceMotion(context) ? 0.0 : _c.value;
        final alpha = 0.35 + 0.35 * t;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: alpha),
            borderRadius: radiusTop
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
