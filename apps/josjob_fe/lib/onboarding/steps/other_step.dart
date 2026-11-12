part of '../onboarding_page.dart';

// ---- Step 2 (personal): Other -------------------------------------------
class _OtherStep extends StatelessWidget {
  final _OnboardingFlowState state;
  const _OtherStep({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MultiSelectInput(
          label: 'Hobbies',
          hint: 'Add a hobby',
          icon: Icons.interests_outlined,
          selected: state._hobbies,
          onChanged: state.refresh,
        ),
        const SizedBox(height: 24),
        _MultiSelectInput(
          label: 'Other industries you are interested in',
          hint: 'Search or add an industry',
          icon: Icons.factory_outlined,
          suggestions: MasterData.instance.industries,
          selected: state._otherIndustries,
          onChanged: state.refresh,
        ),
        const SizedBox(height: 24),
        _MultiSelectInput(
          label: 'Other professions you are interested in',
          hint: 'Search or add a profession',
          icon: Icons.work_outline,
          suggestions: MasterData.instance.professions,
          selected: state._otherProfessions,
          onChanged: state.refresh,
        ),
        const SizedBox(height: 24),
        _MultiSelectInput(
          label: 'Other countries you are interested in',
          hint: 'Search or add a country',
          icon: Icons.public_outlined,
          suggestions: MasterData.instance.countries,
          selected: state._otherCountries,
          onChanged: state.refresh,
        ),
      ],
    );
  }
}
