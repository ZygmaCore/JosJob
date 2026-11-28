// =========================================================================
// Shared account role, used by the onboarding flow and the dashboard.
//
// Kept in a neutral shared library (rather than inside the onboarding
// library) so the dashboard can render role-adaptive content without a
// circular import between onboarding and dashboard.
// =========================================================================

enum OnboardRole { employer, coordinator, worker, graduate }
