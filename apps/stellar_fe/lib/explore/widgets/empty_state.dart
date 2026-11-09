part of '../explore_page.dart';

// =========================================================================
// The non-grid states: an empty catalog (nothing shared with you yet), a
// no-match state (filters exclude everything, with recovery), and a load
// error (with retry). All share the same centred card chrome.
// =========================================================================

/// Empty state — either the catalog itself is empty, or the current filters
/// match nothing (recovery-oriented, each action loosens a constraint).
class _EmptyState extends StatelessWidget {
  final bool catalogEmpty;
  final String query;
  final bool hasFilters;
  final bool industryActive;
  final VoidCallback? onClearAll;
  final VoidCallback? onDropIndustry;

  const _EmptyState.catalog()
    : catalogEmpty = true,
      query = '',
      hasFilters = false,
      industryActive = false,
      onClearAll = null,
      onDropIndustry = null;

  const _EmptyState.noMatch({
    required this.query,
    required this.hasFilters,
    required this.industryActive,
    required this.onClearAll,
    required this.onDropIndustry,
  }) : catalogEmpty = false;

  @override
  Widget build(BuildContext context) {
    if (catalogEmpty) {
      return _StatePanel(
        icon: Icons.school_outlined,
        title: 'No courses available yet',
        message:
            'There are no courses shared with you right now. Once your '
            'organisation adds courses, they will show up here.',
      );
    }

    final suggestions = <Widget>[
      if (industryActive && onDropIndustry != null)
        _suggest('All industries', onDropIndustry!),
    ];

    return _StatePanel(
      icon: Icons.search_off,
      title: 'No courses match those filters yet',
      message: query.trim().isNotEmpty
          ? 'Nothing matches "${query.trim()}" with your current filters. '
                'Try widening the search.'
          : 'Try loosening a filter to see more courses.',
      children: [
        if (hasFilters && onClearAll != null) ...[
          const SizedBox(height: 22),
          _PillButton('Clear all filters', onPressed: onClearAll!),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Or widen by:',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.body),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: suggestions,
          ),
        ],
      ],
    );
  }

  Widget _suggest(String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.tintBlue,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          focusColor: AppColors.focus,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: AppColors.brandBlue),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Load-failure state with a retry action.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load courses",
      message: message,
      children: [
        const SizedBox(height: 22),
        _PillButton('Try again', trailing: Icons.refresh, onPressed: onRetry),
      ],
    );
  }
}

/// Shared centred card chrome for the empty / error states.
class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.tintBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.iconBlue),
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: _lead(context).copyWith(fontSize: 14.5),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
