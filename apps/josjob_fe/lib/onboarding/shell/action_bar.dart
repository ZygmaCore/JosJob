part of '../onboarding_page.dart';

// =========================================================================
// Bottom action bar
// =========================================================================
class _ActionBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onContinue;
  final VoidCallback? onSkipStep;
  final String continueLabel;
  final bool busy;
  final bool showBack;
  const _ActionBar({
    required this.onBack,
    required this.onContinue,
    required this.onSkipStep,
    required this.continueLabel,
    required this.busy,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _compact(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20 : 32,
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onSkipStep != null) ...[
                    Semantics(
                      button: true,
                      label: 'Skip this step',
                      child: TextButton(
                        onPressed: onSkipStep,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.body,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        child: Text(
                          'Skip this step',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      if (showBack)
                        _GhostButton(
                          label: 'Back',
                          onPressed: busy ? null : onBack,
                        ),
                      if (showBack) const SizedBox(width: 12),
                      Expanded(
                        child: _PillButton(
                          label: continueLabel,
                          onPressed: onContinue,
                          busy: busy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
