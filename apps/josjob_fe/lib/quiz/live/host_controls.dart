part of '../quiz_page.dart';

/// Bottom action bar shown when "presenter" mode is on — the instructor /
/// co-host control that pushes the current stage forward, mirroring who drives
/// the real quiz channel. Hidden entirely otherwise.
class _HostControls extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _HostControls({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.co_present, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Presenter · instructor / co-host',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onNavyDim,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _PillButton(
                label,
                kind: _BtnKind.light,
                trailing: icon,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
