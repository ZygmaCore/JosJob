part of '../dashboard_page.dart';

// =========================================================================
// AI teaching-assistant promo card — navy -> brandBlue gradient with white
// text and a translucent "Ask AI" pill. Same in both views.
// =========================================================================
class _AiAssistantCard extends StatelessWidget {
  const _AiAssistantCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [_cardShadow],
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.brandBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Teaching Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Ask anything about your courses, 24/7.',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.onNavyDim,
            ),
          ),
          const SizedBox(height: 18),
          _AskAiButton(onPressed: () => _demoAction(context)),
        ],
      ),
    );
  }
}

// White / translucent pill sitting on the navy gradient.
class _AskAiButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AskAiButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ask AI',
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ask AI',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
