part of '../vod_page.dart';

// =========================================================================
// Page chrome + full-panel states: top bar, initial loading spinner, the
// load/error/processing message, and the per-tab empty state.
// =========================================================================

// Slim top bar: back button + video title.
class _VodTopBar extends StatelessWidget {
  final String title;
  const _VodTopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.navy,
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.play_lesson_outlined,
            size: 20,
            color: AppColors.brandBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/vod/document'),
            icon: const Icon(Icons.file_upload_outlined),
            color: AppColors.brandBlue,
            tooltip: 'Upload a video',
          ),
        ],
      ),
    );
  }
}

class _VodLoading extends StatelessWidget {
  const _VodLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
      ),
    ),
  );
}

// A centered icon + title + message + "Try again" — used for load failures and
// while a video is still processing.
class _VodMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _VodMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.body),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.body,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  focusColor: AppColors.focus,
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try again',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty state inside a panel tab (no topics / no transcript).
class _PanelEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PanelEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.body.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: AppColors.body,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
