part of '../auth_page.dart';

// Split-screen kicks in at the desktop breakpoint; below is a single column.
bool _wide(BuildContext c) => MediaQuery.sizeOf(c).width >= Bp.desktop;
// Tighter type/padding on small phones.
bool _compact(BuildContext c) => MediaQuery.sizeOf(c).width < 600;

TextStyle _titleStyle(BuildContext c) => GoogleFonts.poppins(
  fontSize: _compact(c) ? 26 : 32,
  height: 1.14,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
  letterSpacing: -0.5,
);

TextStyle _subStyle(BuildContext c) =>
    GoogleFonts.poppins(fontSize: 15, height: 1.55, color: AppColors.body);

// -------------------------------------------------------------------------
// Navigation helpers
// -------------------------------------------------------------------------
void _backToSite(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
    );
  }
}

// Returning users land in the app after logging in. Uses the named /dashboard
// route (no stored role -> the default learner view, with the Learn|Jobs
// switcher), clearing the auth stack behind it.
void _goDashboard(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
}

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$what is coming soon'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// -------------------------------------------------------------------------
// Validators (shared, referenced by both fields and focus-management)
// -------------------------------------------------------------------------
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? _validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter your email address.';
  if (!_emailRe.hasMatch(s)) return 'That doesn\'t look like a valid email.';
  return null;
}

String? _validateName(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter your name.';
  if (s.length < 2) return 'Please enter your full name.';
  return null;
}

String? _validatePassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Create a password.';
  if (s.length < 8) return 'Use at least 8 characters.';
  return null;
}

// Generic "this field can't be empty" check — used by the organization detail
// fields on the create-account form.
String? _validateRequired(String? v) =>
    (v == null || v.trim().isEmpty) ? 'This field is required.' : null;

// Trim a text-field value; treat empty/whitespace-only as "not provided" so
// optional fields are omitted from the request rather than sent blank.
String? _blankToNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

const Color _errorRed = Color(0xFFC62828); // ~5.9:1 on white — AA at 12.5px

// -------------------------------------------------------------------------
// Date of birth — friendly display + the ISO (yyyy-MM-dd) wire format the
// backend `birthdate` :date attribute expects.
// -------------------------------------------------------------------------
const _dobMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDob(DateTime d) =>
    '${d.day} ${_dobMonths[d.month - 1]} ${d.year}';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
