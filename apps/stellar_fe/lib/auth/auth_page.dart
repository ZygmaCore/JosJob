import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing/landing_page_ascent.dart'
    show AppColors, Bp, StellarLandingPage;
import '../onboarding/onboarding_page.dart' show OnboardingFlow;
import '../services/api_config.dart' show ApiConfig;
import '../services/auth_api.dart' show AuthException, AccountType;
import '../services/session.dart';
import 'org_pending_page.dart' show OrgPendingPage;
import 'widgets/google_auth.dart';

// =========================================================================
// ATVETI STELLAR — Authentication (Log in / Create account)
// Employee-focused auth screens matching the landing-page design system
// (blue palette in AppColors, Poppins, pill buttons, rounded cards).
//
// Responsive: desktop (>=1024) is a split screen — a navy brand panel beside
// the form; below that it collapses to a single centered card. Both pages are
// wired to the backend auth API (see lib/services + docs/api/auth.md): log in →
// dashboard, register → onboarding, plus Google sign-in. Reachable via named
// routes /login & /register.
// =========================================================================

part 'data/helpers.dart';
part 'screens/login_page.dart';
part 'screens/register_page.dart';
part 'shell/auth_shell.dart';
part 'shell/form_side.dart';
part 'shell/auth_form_body.dart';
part 'shell/brand_panel.dart';
part 'shell/brand_logo.dart';
part 'shell/back_to_site.dart';
part 'widgets/auth_field.dart';
part 'widgets/date_field.dart';
part 'widgets/account_type_field.dart';
part 'widgets/password_toggle.dart';
part 'widgets/remember_me.dart';
part 'widgets/terms_check.dart';
part 'widgets/check_box.dart';
part 'widgets/primary_button.dart';
part 'widgets/form_error.dart';
part 'widgets/or_divider.dart';
part 'widgets/social_row.dart';
part 'widgets/social_button.dart';
part 'widgets/google_glyph.dart';
part 'shell/auth_success.dart';
