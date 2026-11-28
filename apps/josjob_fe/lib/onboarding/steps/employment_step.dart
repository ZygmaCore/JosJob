part of '../onboarding_page.dart';

// ---- Step 0 (personal): Employment --------------------------------------
class _EmploymentStep extends StatefulWidget {
  final _OnboardingFlowState state;
  final OnboardRole role;
  const _EmploymentStep({required this.state, required this.role});

  @override
  State<_EmploymentStep> createState() => _EmploymentStepState();
}

class _EmploymentStepState extends State<_EmploymentStep> {
  // Draft "company" sub-form.
  String? _industry;
  final _company = TextEditingController();
  String? _country;
  bool _internship = false;
  final _position = TextEditingController();
  _MonthYear? _from;
  _MonthYear? _to;
  int _gen = 0; // bumps to rebuild (reset) the draft sub-form after an add

  @override
  void dispose() {
    _company.dispose();
    _position.dispose();
    super.dispose();
  }

  void _addCompany() {
    if (_company.text.trim().isEmpty) return;
    setState(() {
      widget.state._employments.add(
        _Employment(
          industry: _industry ?? '',
          name: _company.text.trim(),
          country: _country ?? '',
          internship: _internship,
          position: _position.text.trim(),
          from: _from,
          to: _to,
        ),
      );
      _industry = null;
      _company.clear();
      _country = null;
      _internship = false;
      _position.clear();
      _from = null;
      _to = null;
      _gen++;
    });
    widget.state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final isStudent = widget.role == OnboardRole.graduate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Company'),
        const SizedBox(height: 12),
        for (int i = 0; i < st._employments.length; i++)
          _EntryCard(
            icon: Icons.business_center_outlined,
            title: st._employments[i].name,
            lines: [
              st._employments[i].position,
              [
                st._employments[i].industry,
                st._employments[i].country,
              ].where((s) => s.isNotEmpty).join('  ·  '),
              [
                _periodLabel(st._employments[i].from, st._employments[i].to),
                if (st._employments[i].internship) 'Internship',
              ].where((s) => s.isNotEmpty).join('  ·  '),
            ],
            onRemove: () => setState(() => st._employments.removeAt(i)),
          ),
        KeyedSubtree(
          key: ValueKey('emp$_gen'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectField(
                label: 'Industry',
                hint: 'Select industry',
                icon: Icons.factory_outlined,
                value: _industry,
                items: MasterData.instance.industries,
                onChanged: (v) => setState(() => _industry = v),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Name',
                hint: 'Company or employer',
                icon: Icons.apartment_outlined,
                controller: _company,
              ),
              const SizedBox(height: 14),
              _SelectField(
                label: 'Country',
                hint: 'Select country',
                icon: Icons.public_outlined,
                value: _country,
                items: MasterData.instance.countries,
                onChanged: (v) => setState(() => _country = v),
              ),
              if (isStudent) ...[
                const SizedBox(height: 14),
                _CheckTile(
                  label: 'Internship?',
                  selected: _internship,
                  onTap: () => setState(() => _internship = !_internship),
                ),
              ],
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Position',
                hint: 'e.g. Front Office Associate',
                icon: Icons.badge_outlined,
                controller: _position,
              ),
              const SizedBox(height: 14),
              _PeriodRow(
                from: _from,
                to: _to,
                onFrom: (v) => setState(() => _from = v),
                onTo: (v) => setState(() => _to = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _GhostButton(
            label: 'Add company',
            icon: Icons.add,
            onPressed: _addCompany,
          ),
        ),
        const SizedBox(height: 28),
        _MultiSelectInput(
          label: 'Skills related to industries',
          hint: _industry == null
              ? 'Pick an industry above to see related skills, or add your own'
              : 'Search or add a skill',
          icon: Icons.add_task_outlined,
          // Scope suggestions to the industry picked in the draft above (plus
          // always-available general skills); general-only until one is chosen.
          suggestions: MasterData.instance.skillsForIndustry(
            _industry == null
                ? null
                : MasterData.instance.industryId(_industry!),
          ),
          selected: st._skills,
          onChanged: st.refresh,
        ),
      ],
    );
  }
}
