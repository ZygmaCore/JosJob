part of '../live_call_page.dart';

// =========================================================================
// Full-screen states shown before/after the live grid: connecting, not
// configured (Cloudflare Realtime creds missing), error, and ended.
// =========================================================================
class _LiveStatusView extends StatelessWidget {
  const _LiveStatusView._({
    required this.onLeave,
    this.icon,
    this.title,
    this.message,
    this.spinner = false,
    this.leaveLabel = 'Keluar',
  });

  final VoidCallback onLeave;
  final IconData? icon;
  final String? title;
  final String? message;
  final bool spinner;
  final String leaveLabel;

  factory _LiveStatusView.connecting({required VoidCallback onLeave}) =>
      _LiveStatusView._(
        onLeave: onLeave,
        spinner: true,
        title: 'Menyambungkan…',
        message: 'Menyiapkan sesi langsung.',
        leaveLabel: 'Batal',
      );

  factory _LiveStatusView.notConfigured({required VoidCallback onLeave}) =>
      _LiveStatusView._(
        onLeave: onLeave,
        icon: Icons.videocam_off_outlined,
        title: 'Live belum aktif',
        message:
            'Live streaming belum dikonfigurasi di server ini. Hubungi admin '
            'untuk mengaktifkan Cloudflare Realtime.',
      );

  factory _LiveStatusView.error({
    String? message,
    required VoidCallback onLeave,
  }) => _LiveStatusView._(
    onLeave: onLeave,
    icon: Icons.error_outline_rounded,
    title: 'Tidak dapat bergabung',
    message: message ?? 'Terjadi kesalahan saat menyambung ke sesi.',
  );

  factory _LiveStatusView.ended({
    required bool removed,
    required VoidCallback onLeave,
  }) => _LiveStatusView._(
    onLeave: onLeave,
    icon: Icons.check_circle_outline_rounded,
    title: removed ? 'Anda dikeluarkan' : 'Sesi berakhir',
    message: removed
        ? 'Host mengeluarkan Anda dari sesi ini.'
        : 'Sesi ini telah diakhiri oleh host.',
    leaveLabel: 'Selesai',
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 20),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: _poppins(18, weight: FontWeight.w600),
              ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: _poppins(
                  13.5,
                  weight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(height: 28),
            TextButton(
              onPressed: onLeave,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                leaveLabel,
                style: _poppins(14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
