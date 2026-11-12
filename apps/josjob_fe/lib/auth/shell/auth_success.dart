part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Success state (after simulated submit)
// -------------------------------------------------------------------------
class _AuthSuccess extends StatelessWidget {
  final String title;
  final String message;
  final String cta;
  final VoidCallback onCta;
  const _AuthSuccess({
    required this.title,
    required this.message,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.tintGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.iconGreen,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: _titleStyle(context),
          ),
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: _subStyle(context)),
        const SizedBox(height: 28),
        _PrimaryButton(label: cta, busy: false, onPressed: onCta),
      ],
    );
  }
}
