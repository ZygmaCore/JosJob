part of '../auth_page.dart';

class _TermsCheck extends StatefulWidget {
  final bool value;
  final String? error;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onLink;
  const _TermsCheck({
    required this.value,
    required this.error,
    required this.onChanged,
    required this.onLink,
  });

  @override
  State<_TermsCheck> createState() => _TermsCheckState();
}

class _TermsCheckState extends State<_TermsCheck> {
  final TapGestureRecognizer _terms = TapGestureRecognizer();
  final TapGestureRecognizer _privacy = TapGestureRecognizer();

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    // Refresh the tap targets each build so they always call the latest onLink.
    _terms.onTap = widget.onLink;
    _privacy.onTap = widget.onLink;
    final base = GoogleFonts.poppins(
      fontSize: 13.5,
      height: 1.45,
      color: AppColors.body,
    );
    final link = GoogleFonts.poppins(
      fontSize: 13.5,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: AppColors.brandBlue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The padded Checkbox is the toggle (48px target); Terms/Privacy in
            // the label are their own tappable links (open the policy).
            MergeSemantics(
              child: Semantics(
                checked: widget.value,
                label: 'I agree to the Terms and Privacy Policy',
                child: _CheckBox(value: widget.value, onChanged: onChanged),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I agree to the ',
                  style: base,
                  children: [
                    TextSpan(text: 'Terms', style: link, recognizer: _terms),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: link,
                      recognizer: _privacy,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.error!,
                style: GoogleFonts.poppins(fontSize: 12.5, color: _errorRed),
              ),
            ),
          ),
      ],
    );
  }
}
