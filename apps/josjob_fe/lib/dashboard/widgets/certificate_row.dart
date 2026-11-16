part of '../dashboard_page.dart';

// =========================================================================
// One earned-certificate row: award icon tile, title + issuer/date, chevron.
// =========================================================================
class _CertificateRow extends StatelessWidget {
  final _Certificate cert;
  const _CertificateRow(this.cert);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${cert.title}, ${cert.issuer}, ${cert.date}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _demoAction(context),
          borderRadius: BorderRadius.circular(12),
          focusColor: AppColors.focus,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.tintOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.iconOrange,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cert.issuer} · ${cert.date}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.body,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
