part of '../onboarding_page.dart';

// ---- Step 1 (personal): Education ---------------------------------------
class _EducationStep extends StatefulWidget {
  final _OnboardingFlowState state;
  const _EducationStep({required this.state});

  @override
  State<_EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<_EducationStep> {
  // Draft "formal" sub-form.
  String? _degree;
  final _fName = TextEditingController();
  final _fMajor = TextEditingController();
  String? _fCountry;
  String? _fType;
  _MonthYear? _fFrom;
  _MonthYear? _fTo;
  int _fGen = 0;

  // Draft "non-formal / achievement" sub-form.
  String? _aType;
  final _aName = TextEditingController();
  String? _aCountry;
  final _aIssuer = TextEditingController();
  _MonthYear? _aFrom;
  _MonthYear? _aTo;
  int _aGen = 0;

  @override
  void dispose() {
    _fName.dispose();
    _fMajor.dispose();
    _aName.dispose();
    _aIssuer.dispose();
    super.dispose();
  }

  void _addFormal() {
    if (_fName.text.trim().isEmpty) return;
    setState(() {
      widget.state._educations.add(
        _Education(
          degree: _degree ?? '',
          name: _fName.text.trim(),
          major: _fMajor.text.trim(),
          country: _fCountry ?? '',
          type: _fType ?? '',
          from: _fFrom,
          to: _fTo,
        ),
      );
      _degree = null;
      _fName.clear();
      _fMajor.clear();
      _fCountry = null;
      _fType = null;
      _fFrom = null;
      _fTo = null;
      _fGen++;
    });
    widget.state.refresh();
  }

  void _addAchievement() {
    if (_aName.text.trim().isEmpty) return;
    setState(() {
      widget.state._achievements.add(
        _Achievement(
          type: _aType ?? '',
          name: _aName.text.trim(),
          country: _aCountry ?? '',
          issuer: _aIssuer.text.trim(),
          from: _aFrom,
          to: _aTo,
        ),
      );
      _aType = null;
      _aName.clear();
      _aCountry = null;
      _aIssuer.clear();
      _aFrom = null;
      _aTo = null;
      _aGen++;
    });
    widget.state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Formal'),
        const SizedBox(height: 12),
        for (int i = 0; i < st._educations.length; i++)
          _EntryCard(
            icon: Icons.school_outlined,
            title: st._educations[i].name,
            lines: [
              [
                st._educations[i].degree,
                st._educations[i].major,
                st._educations[i].type,
              ].where((s) => s.isNotEmpty).join('  ·  '),
              st._educations[i].country,
              _periodLabel(st._educations[i].from, st._educations[i].to),
            ],
            onRemove: () => setState(() => st._educations.removeAt(i)),
          ),
        KeyedSubtree(
          key: ValueKey('formal$_fGen'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectField(
                label: 'Degree',
                hint: 'Select degree',
                icon: Icons.school_outlined,
                value: _degree,
                items: _degreeOptions,
                onChanged: (v) => setState(() => _degree = v),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Major',
                hint: 'Field of study',
                icon: Icons.menu_book_outlined,
                controller: _fMajor,
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Name',
                hint: 'School / university',
                icon: Icons.apartment_outlined,
                controller: _fName,
              ),
              const SizedBox(height: 14),
              _SelectField(
                label: 'Country',
                hint: 'Select country',
                icon: Icons.public_outlined,
                value: _fCountry,
                items: MasterData.instance.countries,
                onChanged: (v) => setState(() => _fCountry = v),
              ),
              const SizedBox(height: 14),
              _SelectField(
                label: 'Type',
                hint: 'Select type',
                icon: Icons.category_outlined,
                value: _fType,
                items: _educationTypeOptions,
                onChanged: (v) => setState(() => _fType = v),
              ),
              const SizedBox(height: 14),
              _PeriodRow(
                from: _fFrom,
                to: _fTo,
                onFrom: (v) => setState(() => _fFrom = v),
                onTo: (v) => setState(() => _fTo = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _GhostButton(
            label: 'Add education',
            icon: Icons.add,
            onPressed: _addFormal,
          ),
        ),
        const SizedBox(height: 28),
        _FieldLabel('Non-formal education / Achievement'),
        const SizedBox(height: 12),
        for (int i = 0; i < st._achievements.length; i++)
          _EntryCard(
            icon: Icons.workspace_premium_outlined,
            title: st._achievements[i].name,
            lines: [
              st._achievements[i].type,
              st._achievements[i].issuer.isEmpty
                  ? ''
                  : 'Issued by ${st._achievements[i].issuer}',
              st._achievements[i].country,
              _periodLabel(st._achievements[i].from, st._achievements[i].to),
            ],
            onRemove: () => setState(() => st._achievements.removeAt(i)),
          ),
        KeyedSubtree(
          key: ValueKey('ach$_aGen'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectField(
                label: 'Type',
                hint: 'Select type',
                icon: Icons.category_outlined,
                value: _aType,
                items: _achievementTypeOptions,
                onChanged: (v) => setState(() => _aType = v),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Name',
                hint: 'e.g. Certified Scrum Master',
                icon: Icons.badge_outlined,
                controller: _aName,
              ),
              const SizedBox(height: 14),
              _SelectField(
                label: 'Country',
                hint: 'Select country',
                icon: Icons.public_outlined,
                value: _aCountry,
                items: MasterData.instance.countries,
                onChanged: (v) => setState(() => _aCountry = v),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Issued / Held by',
                hint: 'e.g. Coursera',
                icon: Icons.verified_outlined,
                controller: _aIssuer,
              ),
              const SizedBox(height: 14),
              _PeriodRow(
                from: _aFrom,
                to: _aTo,
                onFrom: (v) => setState(() => _aFrom = v),
                onTo: (v) => setState(() => _aTo = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _GhostButton(
            label: 'Add achievement',
            icon: Icons.add,
            onPressed: _addAchievement,
          ),
        ),
      ],
    );
  }
}
