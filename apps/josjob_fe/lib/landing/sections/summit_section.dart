part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Summit — get-started CTA
// -------------------------------------------------------------------------
class _SummitSection extends StatefulWidget {
  const _SummitSection({super.key});
  @override
  State<_SummitSection> createState() => _SummitSectionState();
}

class _SummitSectionState extends State<_SummitSection> {
  final _controller = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() {
      _error = ok ? null : 'Please enter a valid email address.';
      if (ok) _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return ColoredBox(
      color: AppColors.bg,
      child: _Bounded(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 40 : 64),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 24 : 56,
              vertical: mobile ? 44 : 72,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.heroBlue, AppColors.brandBlue],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.brandBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'GET STARTED',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Ready to grow your skills and land your next role?',
                    textAlign: TextAlign.center,
                    style: _h2s(context, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Tell us your goals and we\'ll help you build job-ready '
                    'skills, earn the certifications that matter, and get '
                    'matched with the employers who are hiring.',
                    textAlign: TextAlign.center,
                    style: _lead(context, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 28),
                if (_sent)
                  _Sent(email: _controller.text.trim())
                else
                  _EnquiryForm(
                    controller: _controller,
                    error: _error,
                    onSubmit: _submit,
                    mobile: mobile,
                  ),
                const SizedBox(height: 26),
                Text(
                  'Prefer to talk?',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _ContactChip(Icons.mail_outline, 'hello@atveti.com'),
                    _ContactChip(Icons.call_outlined, '+61 439 158 812'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
