part of '../landing_page_ascent.dart';

class _FooterCol extends StatelessWidget {
  final String heading;
  final List<String> links;
  const _FooterCol(this.heading, this.links);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {},
              focusColor: AppColors.focus,
              child: Text(
                link,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.onNavyDim,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
