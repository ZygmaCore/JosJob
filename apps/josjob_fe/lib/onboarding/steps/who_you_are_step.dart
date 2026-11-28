part of '../onboarding_page.dart';

// =========================================================================
// "Who you are" — identity details + sub-role. Only personal accounts reach
// onboarding (organizations register and land on the pending screen), so the
// choices here are personal sub-roles only. A Google sign-in that still has no
// account type is set to personal on confirm via _confirmIdentity.
// =========================================================================
class _WhoYouAreStep extends StatefulWidget {
  final _OnboardingFlowState state;
  const _WhoYouAreStep({super.key, required this.state});

  @override
  State<_WhoYouAreStep> createState() => _WhoYouAreStepState();
}

class _WhoYouAreStepState extends State<_WhoYouAreStep> {
  // Only personal accounts reach onboarding, so the sub-roles are personal
  // only. (Organizations register on the create-account form and go straight
  // to the pending screen — they never see this step.)
  static const List<OnboardRole> _availableRoles = [
    OnboardRole.worker,
    OnboardRole.graduate,
  ];

  void _pickRole(OnboardRole r) {
    setState(() => widget.state._pendingRole = r);
    widget.state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return _ContentShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: "Let's get to know you",
            subtitle:
                "Confirm your details and tell us how you're joining — "
                'this tailors the rest of your setup.',
          ),
          _LabeledField(
            label: 'Full name',
            icon: Icons.person_outline,
            controller: st._fullName,
            onChanged: (_) => st.refresh(),
          ),
          const SizedBox(height: 18),
          _LabeledField(
            label: 'Email',
            icon: Icons.mail_outline,
            controller: st._email,
            readOnly: true,
          ),
          const SizedBox(height: 18),
          _SelectField(
            label: 'Country',
            hint: 'Select country',
            icon: Icons.public_outlined,
            value: st._country,
            items: MasterData.instance.countries,
            onChanged: (v) {
              setState(() {
                st._country = v;
                // Default the phone dial code to the chosen country (still
                // changeable via the phone field's own code picker).
                final code = v == null
                    ? null
                    : MasterData.instance.countryPhoneCode(v);
                if (code != null && code.isNotEmpty) st._phoneDial = code;
              });
              st.refresh();
            },
          ),
          const SizedBox(height: 18),
          _PhoneField(
            label: 'Phone',
            dialCode: st._phoneDial,
            controller: st._phone,
            onDialCode: (dial) {
              setState(() => st._phoneDial = dial);
              st.refresh();
            },
          ),
          const SizedBox(height: 18),
          _LabeledField(
            label: 'Address',
            hint: 'City, Country',
            icon: Icons.location_on_outlined,
            controller: st._address,
          ),
          const SizedBox(height: 24),
          _FieldLabel('Which best describes you?', required: true),
          const SizedBox(height: 10),
          for (final r in _availableRoles) ...[
            _RadioTile(
              label: r.label,
              selected: st._pendingRole == r,
              enabled: !st._submitting,
              onTap: () => _pickRole(r),
            ),
            const SizedBox(height: 10),
          ],
          if (st._identityError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
              child: Text(
                st._identityError!,
                style: GoogleFonts.poppins(fontSize: 13, color: _errorRed),
              ),
            ),
        ],
      ),
    );
  }
}
