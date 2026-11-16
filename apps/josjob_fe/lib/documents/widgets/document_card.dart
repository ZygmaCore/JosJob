part of '../documents_page.dart';

// A single document row: media-type icon, title/description, a relationship
// chip, and actions (Open; Share when the caller can manage access).
class _DocumentCard extends StatelessWidget {
  final DocItem doc;
  final VoidCallback onOpen;
  final VoidCallback? onShare;

  const _DocumentCard({required this.doc, required this.onOpen, this.onShare});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: doc.isVideo ? AppColors.tintBlue : AppColors.tintOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                doc.isVideo
                    ? Icons.play_circle_outline_rounded
                    : Icons.description_outlined,
                color: doc.isVideo ? AppColors.iconBlue : AppColors.iconOrange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title.isEmpty ? 'Untitled' : doc.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if ((doc.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      doc.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.body,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _RelationshipChip(relationship: doc.relationship),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CardAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Open',
                  onTap: onOpen,
                ),
                if (onShare != null) ...[
                  const SizedBox(height: 6),
                  _CardAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Share',
                    highlighted: true,
                    onTap: onShare!,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.brandBlue : AppColors.body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A small badge naming how the caller relates to the document.
class _RelationshipChip extends StatelessWidget {
  final String relationship;
  const _RelationshipChip({required this.relationship});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (relationship) {
      'owner' => ('Owner', AppColors.tintGreen, AppColors.iconGreen),
      'org' => ('Organization', AppColors.tintBlue, AppColors.iconBlue),
      'admin' => ('Admin', AppColors.tintBlue, AppColors.iconBlue),
      _ => ('Shared with you', AppColors.tintOrange, AppColors.iconOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
