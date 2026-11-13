part of '../landing_page_ascent.dart';

class _FooterCol extends StatelessWidget {
  final String heading;
  final List<String> links;
  final ValueChanged<String>? onTap;
  const _FooterCol(this.heading, this.links, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.landingInk,
          ),
        ),
        const SizedBox(height: 16),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => onTap?.call(link),
              focusColor: AppColors.primaryDeep,
              child: Text(
                link,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
