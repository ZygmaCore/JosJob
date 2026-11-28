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
  final _focus = FocusNode();
  bool _focused = false;
  void _toggle() => setState(() => _open = !_open);
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: true,
          label: widget.faq.$1,
          excludeSemantics: true,
          onTap: _toggle,
          expanded: _open,
          focusable: true,
          focused: _focused,
          onFocus: _focus.requestFocus,
          onDidGainAccessibilityFocus: _focus.requestFocus,
          child: InkWell(
            focusNode: _focus,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: _toggle,
            focusColor: AppColors.focus,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.$1,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    _open ? Icons.remove : Icons.add,
                    size: 18,
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
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text(
              widget.faq.$2,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.body,
                height: 1.7,
              ),
            ),
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: _anim(context, 180),
        ),
      ],
    ),
  );
}
