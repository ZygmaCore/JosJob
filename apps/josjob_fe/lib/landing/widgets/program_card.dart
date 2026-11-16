part of '../landing_page_ascent.dart';

class _ProgramCard extends StatelessWidget {
  final _Item item;
  const _ProgramCard(this.item);

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      builder: (hovered) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: item.tint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hovered ? item.iconColor : AppColors.rule),
          boxShadow: [
            BoxShadow(
              color: AppColors.landingInk.withValues(
                alpha: hovered ? .12 : .06,
              ),
              blurRadius: hovered ? 14 : 8,
              offset: const Offset(5, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.cotton,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              item.title,
              style: TextStyle(
                fontFamily: 'General Sans',
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.landingInk,
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
