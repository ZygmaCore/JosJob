part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Inline error banner — shown when a backend auth call fails (wrong
// credentials, email already registered, unreachable server, …).
// -------------------------------------------------------------------------
class _FormError extends StatelessWidget {
  final String message;
  const _FormError(this.message);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _errorRed.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 20, color: _errorRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.4,
                  color: _errorRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
