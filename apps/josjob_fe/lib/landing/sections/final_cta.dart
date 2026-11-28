part of '../landing_page_ascent.dart';

class _FinalCta extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _FinalCta({required this.onGetStarted});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.board,
    child: _Bounded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _isMobile(context) ? 48 : 72),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final message = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Eyebrow(
                  'FOR GRADUATES AND EMPLOYERS',
                  color: AppColors.boardText,
                ),
                const SizedBox(height: 14),
                Text(
                  'Make the next step count.',
                  style: _h2s(context, color: AppColors.boardText),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Explore roles and build skills, or publish a job directly from your verified organization workspace.',
                    style: _lead(context, color: AppColors.boardText),
                  ),
                ),
              ],
            );
            final action = _PillButton(
              'Get started',
              kind: _BtnKind.white,
              trailing: Icons.arrow_forward,
              onPressed: onGetStarted,
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [message, const SizedBox(height: 24), action],
                  )
                : Row(
                    children: [
                      Expanded(child: message),
                      const SizedBox(width: 32),
                      action,
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
