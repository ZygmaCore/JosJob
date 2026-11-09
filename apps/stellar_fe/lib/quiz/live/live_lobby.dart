part of '../quiz_page.dart';

/// The "get ready" waiting room shown before the first question is pushed.
class _LiveLobby extends StatelessWidget {
  final String title;
  final int joined;
  final int totalQuestions;
  const _LiveLobby({
    required this.title,
    required this.joined,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandBlue, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 54),
            ),
            const SizedBox(height: 26),
            Text(
              'Get ready!',
              style: GoogleFonts.poppins(
                fontSize: _isMobile(context) ? 30 : 38,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _TagPill(
                  '$joined in the room',
                  fg: AppColors.brandBlue,
                  bg: AppColors.tintBlue,
                  icon: Icons.people_alt_outlined,
                ),
                _TagPill(
                  '$totalQuestions questions',
                  fg: AppColors.iconOrange,
                  bg: AppColors.tintOrange,
                  icon: Icons.help_outline,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.brandBlue,
                    ),
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Waiting for the host to start…',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
