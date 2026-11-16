import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing/landing_page_ascent.dart' show AppColors;
import '../shared/onboard_role.dart';
import '../dashboard/dashboard_page.dart';
import '../services/session.dart';
import '../services/auth_api.dart' show AccountType, AuthException;
import '../services/onboarding_draft.dart';
import '../services/masterdata.dart';
import '../services/sync/sync_engine.dart';

// =========================================================================
// JosJob — User Onboarding Flow (UI only, no backend)
//
// Reached after a successful "Create account" on the register page (personal
// accounts only). Starts on a "Who you are" identity screen, then runs a
// multi-step session, ending in "Onboarding complete" → dashboard.
//
//   Who you are  →  Employment → Education → Other → Complete  →  Dashboard
//
// Corporation / Institution accounts do NOT reach this flow at all — they
// capture their details on the create-account form and land on the "request
// received" screen (see auth/org_pending_page.dart).
//
// Design system is inherited from the landing/auth pages: AppColors blue
// palette, Poppins, pill buttons, rounded cards. Everything is local state —
// no persistence. Progress indicator, predictable back, and reduced-motion
// transitions follow the app's UX conventions.
// =========================================================================

part 'data/helpers.dart';
part 'data/models.dart';
part 'data/draft.dart';
part 'data/data.dart';
part 'data/role_ext.dart';
part 'shell/onboarding_flow.dart';
part 'shell/top_bar.dart';
part 'shell/segmented_progress.dart';
part 'shell/brand_logo.dart';
part 'shell/transitioner.dart';
part 'shell/content_shell.dart';
part 'shell/step_header.dart';
part 'steps/who_you_are_step.dart';
part 'steps/step_body.dart';
part 'steps/employment_step.dart';
part 'steps/education_step.dart';
part 'steps/other_step.dart';
part 'steps/complete_screen.dart';
part 'shell/action_bar.dart';
part 'shell/skip_dialog.dart';
part 'widgets/removable_chip.dart';
part 'widgets/radio_tile.dart';
part 'widgets/check_tile.dart';
part 'widgets/entry_card.dart';
part 'widgets/field_label.dart';
part 'widgets/labeled_field.dart';
part 'widgets/select_field.dart';
part 'widgets/phone_field.dart';
part 'widgets/month_year_field.dart';
part 'widgets/period_row.dart';
part 'widgets/multi_select_input.dart';
part 'widgets/pill_button.dart';
part 'widgets/ghost_button.dart';
