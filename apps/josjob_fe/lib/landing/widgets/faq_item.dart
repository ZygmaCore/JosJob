part of '../landing_page_ascent.dart';

class _FaqItem extends StatefulWidget {
  final String index;
  final (String, String) faq;
  final bool initiallyOpen;
  const _FaqItem(this.index, this.faq, {this.initiallyOpen = false});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  late bool _open = widget.initiallyOpen;
  @override
  Widget build(BuildContext context) {
    final (q, a) = widget.faq;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: q,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              focusColor: AppColors.focus,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Text(
                      widget.index,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        q,
                        style: GoogleFonts.poppins(
                          fontSize: _isMobile(context) ? 17 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      _open ? Icons.remove : Icons.add,
                      color: AppColors.brandBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 46, right: 24),
              child: Text(a, style: _lead(context).copyWith(fontSize: 15.5)),
            ),
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: _anim(context, 200),
          ),
        ],
      ),
    );
  }
}
