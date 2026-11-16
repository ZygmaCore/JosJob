part of '../auth_page.dart';

// -------------------------------------------------------------------------
// Registration type picker for the create-account form.
//
// Two mutually-exclusive options: Personal (any email) vs Corporation or
// Institution (a work email is required — enforced by the backend, which
// rejects free-provider addresses). Styled to match the auth design system.
// -------------------------------------------------------------------------
class _AccountTypeField extends StatelessWidget {
  final AccountType? value;
  final ValueChanged<AccountType> onChanged;
  final bool enabled;
  final String? error;

  const _AccountTypeField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.error,
  });

  static const _labels = <AccountType, String>{
    AccountType.personal: 'Personal',
    AccountType.organization: 'Corporation or Institution',
  };

  static const _subtitles = <AccountType, String>{
    AccountType.personal: 'For individuals — any email works.',
    AccountType.organization: 'Requires a work email (no free providers).',
  };

  @override
  Widget build(BuildContext context) {
    final invalid = error != null && value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            'Registration type',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        for (final t in AccountType.values) ...[
          _tile(t, invalid: invalid),
          if (t != AccountType.values.last) const SizedBox(height: 10),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              error!,
              style: GoogleFonts.poppins(fontSize: 12.5, color: _errorRed),
            ),
          ),
      ],
    );
  }

  Widget _tile(AccountType t, {required bool invalid}) {
    final selected = value == t;
    final borderColor = selected
        ? AppColors.brandBlue
        : (invalid ? _errorRed : AppColors.border);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: _labels[t],
      child: Material(
        color: selected ? AppColors.tintBlue : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? () => onChanged(t) : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.6 : 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected ? AppColors.brandBlue : AppColors.body,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labels[t]!,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitles[t]!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.body,
                          ),
                        ),
                      ],
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
