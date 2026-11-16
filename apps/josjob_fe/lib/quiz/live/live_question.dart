part of '../quiz_page.dart';

/// The live question view, used for BOTH the active question (countdown +
/// selectable tiles) and the reveal (correct tile highlighted + points panel).
class _LiveQuestionView extends StatelessWidget {
  final _LiveQuestion question;
  final int number;
  final int total;
  final int remaining;
  final bool revealed;
  final String? selectedKey;
  final int earned;
  final int rank;
  final int totalPlayers;
  final ValueChanged<String> onSelect;
  const _LiveQuestionView({
    required this.question,
    required this.number,
    required this.total,
    required this.remaining,
    required this.revealed,
    required this.selectedKey,
    required this.earned,
    required this.rank,
    required this.totalPlayers,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selectedKey != null;
    return SingleChildScrollView(
      child: _Bounded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  _TagPill(
                    'Question $number of $total',
                    fg: AppColors.brandBlue,
                    bg: AppColors.tintBlue,
                  ),
                  const Spacer(),
                  if (!revealed && answered)
                    _TagPill(
                      'Locked in',
                      fg: AppColors.iconGreen,
                      bg: AppColors.tintGreen,
                      icon: Icons.lock_outline,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: revealed
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.iconGreen,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Answer revealed',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.iconGreen,
                            ),
                          ),
                        ],
                      )
                    : _CountdownRing(
                        remaining: remaining,
                        total: question.seconds,
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: _isMobile(context) ? 20 : 25,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 22),
              _grid(context),
              if (!revealed && !answered) ...[
                const SizedBox(height: 14),
                Text(
                  'Tap your answer — the faster you are, the more points you earn.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
              ],
              if (revealed) ...[
                const SizedBox(height: 22),
                _RevealPanel(
                  earned: earned,
                  correct: selectedKey == question.correctKey,
                  rank: rank,
                  totalPlayers: totalPlayers,
                  explanation: question.explanation,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    const gap = 12.0;
    const tileH = 88.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 2 : 1;
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < question.options.length; i++)
              SizedBox(
                width: itemW,
                height: tileH,
                child: _LiveOptionTile(
                  index: i,
                  option: question.options[i],
                  selected: selectedKey == question.options[i].key,
                  dimmed:
                      !revealed &&
                      selectedKey != null &&
                      selectedKey != question.options[i].key,
                  revealed: revealed,
                  isCorrect: question.options[i].key == question.correctKey,
                  onTap: (!revealed && selectedKey == null)
                      ? () => onSelect(question.options[i].key)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
