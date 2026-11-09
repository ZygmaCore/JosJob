part of '../onboarding_page.dart';

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  // When false the tile is read-only (dimmed, not tappable) — used to show a
  // locked choice (e.g. a registration type already set at sign-up).
  final bool enabled;
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: enabled,
        enabled: enabled,
        label: label,
        child: Material(
          color: selected ? AppColors.tintBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            focusColor: AppColors.focus,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.brandBlue : AppColors.border,
                  width: selected ? 1.6 : 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
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
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
