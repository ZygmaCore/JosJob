part of '../dashboard_page.dart';

// =========================================================================
// Org training-offering card: title, enrolled count, and an average-progress
// bar. Tappable (demo).
// =========================================================================
class _OfferingCard extends StatelessWidget {
  final _DashCourse offering;
  const _OfferingCard(this.offering);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${offering.title}, ${offering.enrolled} learners enrolled, '
          '${(offering.progress * 100).round()} percent average progress',
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => _demoAction(context),
          focusColor: AppColors.focus,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tintBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.library_books_outlined,
                        color: AppColors.iconBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        offering.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${offering.enrolled} learners enrolled',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressBar(value: offering.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
