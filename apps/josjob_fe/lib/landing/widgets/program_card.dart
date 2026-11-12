part of '../landing_page_ascent.dart';

class _ProgramCard extends StatelessWidget {
  final _Item item;
  const _ProgramCard(this.item);

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      builder: (hovered) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: item.tint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hovered ? item.iconColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              item.title,
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            if (item.bullets != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in item.bullets!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 9, right: 10),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: item.iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              b,
                              style: _lead(context).copyWith(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              Text(item.body, style: _lead(context).copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
