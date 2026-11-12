part of '../explore_page.dart';

/// Slim footer strip (navy) closing the page.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      child: _Bounded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Flex(
            direction: mobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'JosJob',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (mobile) const SizedBox(height: 12) else const Spacer(),
              Text(
                '© 2026 JosJob · Workplace-based learning',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.onNavyDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
