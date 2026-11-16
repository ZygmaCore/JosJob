part of '../auth_page.dart';

class _SocialRow extends StatefulWidget {
  final bool enabled;

  // When set (the create-account flow), a brand-new Google sign-in adopts this
  // registration type via the backend right after auth — so the user isn't
  // asked again in onboarding. Null (the login flow) leaves the type untouched.
  final AccountType? accountType;
  const _SocialRow({required this.enabled, this.accountType});

  @override
  State<_SocialRow> createState() => _SocialRowState();
}

class _SocialRowState extends State<_SocialRow> {
  bool _googleBusy = false;

  // Google id_token (from the GIS button) → backend. Anyone who hasn't finished
  // the mandatory onboarding step goes there; everyone else lands on dashboard.
  Future<void> _onGoogleIdToken(String idToken) async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      final session = await Session.instance.signInWithGoogle(idToken);
      // Carry the registration type chosen on the create-account screen into a
      // fresh Google account (the backend leaves it null on sign-up). Existing
      // users keep theirs — setAccountType only accepts a null -> value set.
      final type = widget.accountType;
      if (type != null && session.user.accountType == null) {
        await Session.instance.setAccountType(type);
      }
      if (!mounted) return;
      final user = Session.instance.user!;
      // Organization accounts: un-provisioned ones are pending review;
      // approved ones go straight to the dashboard (org accounts never onboard).
      if (user.accountType == AccountType.organization) {
        if (user.approved) {
          _goDashboard(context);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrgPendingPage()),
          );
        }
      } else if (!user.mandatoryCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingFlow(firstName: user.firstName),
          ),
        );
      } else {
        _goDashboard(context);
      }
    } on AuthException catch (e) {
      // A rejected type (e.g. Company chosen with a free-provider Google email)
      // leaves a signed-in account with no type — sign out so the user can pick
      // again. Only in the create-account flow; login leaves its session alone.
      if (widget.accountType != null &&
          Session.instance.user?.accountType == null) {
        await Session.instance.signOut();
      }
      if (!mounted) return;
      setState(() => _googleBusy = false);
      _snack(e.message);
    }
  }

  void _onGoogleError(Object error) =>
      _snack('Google sign-in failed. Please try again.');

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Google only. The official GIS button appears when a Web client ID is
    // configured (--dart-define=GOOGLE_CLIENT_ID=…); otherwise a decorative pill.
    return ApiConfig.hasGoogleClientId
        ? _GoogleSlot(
            busy: _googleBusy,
            onIdToken: _onGoogleIdToken,
            onError: _onGoogleError,
          )
        : _SocialButton(
            label: 'Google',
            leading: const _GoogleGlyph(),
            onPressed: widget.enabled
                ? () => _soon(context, 'Google sign-in')
                : null,
          );
  }
}

// Renders the GIS button, swapping to a spinner while the backend exchange is
// in flight.
class _GoogleSlot extends StatelessWidget {
  final bool busy;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;
  const _GoogleSlot({
    required this.busy,
    required this.onIdToken,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    return GoogleSignInButton(onIdToken: onIdToken, onError: onError);
  }
}
