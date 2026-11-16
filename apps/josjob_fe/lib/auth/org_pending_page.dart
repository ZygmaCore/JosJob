import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing/landing_page_ascent.dart' show AppColors, JosjobLandingPage;
import '../services/session.dart';

// =========================================================================
// JosJob — Organization "request received" screen
//
// Corporation / Institution accounts do NOT go through onboarding. After they
// register (with their organization details captured on the create-account
// form), and on every later sign-in or reload, they land here: a "we've got
// your request" acknowledgement. Atveti reviews and approves the organization
// out-of-band before its workspace opens, so there is nothing for the account
// to do in-app yet — the only action is to return to the site.
//
// Standalone public page (its own Scaffold) so it can be reached from the
// create-account form, the login flow, the Google flow, and the startup /
// deep-link router alike.
// =========================================================================
class OrgPendingPage extends StatelessWidget {
  const OrgPendingPage({super.key});

  Future<void> _backHome(BuildContext context) async {
    // Capture the navigator before the async gap, then sign out — a pending
    // organization has no in-app session to keep, and signing out means a
    // reload returns to the landing page rather than back here. A storage
    // failure during sign-out must never strand the user on this terminal page:
    // the in-memory session is already cleared, so navigate regardless.
    final navigator = Navigator.of(context);
    try {
      await Session.instance.signOut();
    } catch (_) {
      /* in-memory session already cleared — fall through to navigation */
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.tintOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.iconOrange,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      'Thank you! Your request has been sent to Atveti.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: compact ? 26 : 32,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We'll review your registration and get in touch as soon "
                    'as the process is finished.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.55,
                      color: AppColors.body,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _backHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Back to home',
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
