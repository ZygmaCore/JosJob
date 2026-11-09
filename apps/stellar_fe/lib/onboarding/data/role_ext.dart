part of '../onboarding_page.dart';

// -------------------------------------------------------------------------
// Role model
// -------------------------------------------------------------------------
extension _RoleX on OnboardRole {
  String get label => switch (this) {
    OnboardRole.employer => 'Employer',
    OnboardRole.coordinator => 'Vocational Coordinator',
    OnboardRole.worker => 'Individual Worker / Employee',
    OnboardRole.graduate => 'Student / Graduate',
  };
}
