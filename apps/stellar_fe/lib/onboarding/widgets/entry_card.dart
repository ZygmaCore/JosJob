part of '../onboarding_page.dart';

// A saved Employment / Education / Achievement entry, with a remove button.
class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onRemove;
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final detail = lines.where((l) => l.trim().isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.iconBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                for (final l in detail)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.body,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove $title',
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 20, color: AppColors.body),
              tooltip: 'Remove',
            ),
          ),
        ],
      ),
    );
  }
}
