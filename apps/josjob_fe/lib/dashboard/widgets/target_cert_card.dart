part of '../dashboard_page.dart';

// =========================================================================
// A profile-matched certificate suggestion: award tile, title + provider, the
// reason it's suggested, and an "Add to goals" action.
// =========================================================================
class _TargetCertCard extends StatelessWidget {
  final _TargetCert cert;
  const _TargetCertCard(this.cert);

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cert.provider,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cert.reason,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.4,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              label: 'Add to goals',
              icon: Icons.add,
              variant: _PillVariant.tint,
              onPressed: () => _demoAction(context),
            ),
          ),
        ],
      ),
    );
  }
}
