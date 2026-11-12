part of '../bootstrap_page.dart';

// The branded loading screen shown on web while sqlite3.wasm downloads. Bound
// to a [WasmProgress] sample: a determinate bar + "% · KB / KB" once the total
// is known, an indeterminate bar + downloaded-bytes otherwise.
class _BootSplash extends StatelessWidget {
  const _BootSplash({required this.progress});

  final WasmProgress progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.brandBlue,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'JosJob',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Preparing your offline workspace',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Setting up the on-device database so your work saves even '
                  'when you go offline.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _label(progress),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(WasmProgress p) {
    final kb = (p.received / 1024).round();
    final fraction = p.fraction;
    if (fraction != null) {
      final totalKb = (p.total! / 1024).round();
      return '${(fraction * 100).round()}%   ·   $kb / $totalKb KB';
    }
    return p.received > 0 ? '$kb KB downloaded' : 'Starting…';
  }
}
