part of '../auth_page.dart';

class _AuthFormBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final String footerPrompt;
  final String footerAction;
  final VoidCallback? onFooter;
  const _AuthFormBody({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footerPrompt,
    required this.footerAction,
    required this.onFooter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: _titleStyle(context)),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: _subStyle(context)),
        const SizedBox(height: 28),
        form,
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$footerPrompt ',
              style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.body),
            ),
            InkWell(
              onTap: onFooter,
              borderRadius: BorderRadius.circular(8),
              focusColor: AppColors.focus,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 11,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      footerAction,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
