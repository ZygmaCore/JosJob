part of '../onboarding_page.dart';

// =========================================================================
// Step body dispatcher
// =========================================================================
class _StepBody extends StatelessWidget {
  final OnboardRole role;
  final int step;
  final _OnboardingFlowState state;
  const _StepBody({
    super.key,
    required this.role,
    required this.step,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final meta = state._stepMeta;
    final Widget content = switch (step) {
      0 => _EmploymentStep(state: state, role: role),
      1 => _EducationStep(state: state),
      _ => _OtherStep(state: state),
    };
    return _ContentShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(title: meta.title, subtitle: meta.subtitle),
          content,
        ],
      ),
    );
  }
}
