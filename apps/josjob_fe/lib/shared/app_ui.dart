import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  final double size;
  final bool light, showName;
  const AppBrand({
    super.key,
    this.size = 32,
    this.light = false,
    this.showName = true,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'JosJob',
    image: true,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/branding/josjob-logo.svg',
          width: size,
          height: size,
          excludeFromSemantics: true,
          colorFilter: light
              ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
              : null,
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Text(
            'JosJob',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: light ? Colors.white : AppColors.brandBlue,
            ),
          ),
        ],
      ],
    ),
  );
}

class CompanyAvatar extends StatelessWidget {
  final String name;
  final double size;
  const CompanyAvatar(this.name, {super.key, this.size = 44});
  static String initials(String name) {
    final clean = name
        .replaceAll(
          RegExp(r'\[(?:demo|synthetic[^\]]*)\]', caseSensitive: false),
          '',
        )
        .trim();
    final words = clean
        .split(RegExp(r'\s+'))
        .map((s) => s.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((s) => s.isNotEmpty)
        .take(2);
    return words.isEmpty
        ? '?'
        : words.map((s) => s.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initials(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.brandBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class AppStatusBadge extends StatelessWidget {
  final String label, status;
  const AppStatusBadge({super.key, required this.label, required this.status});
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'hired' ||
      'completed' ||
      'active' ||
      'approved' => (AppColors.tintGreen, AppColors.success),
      'rejected' || 'cancelled' => (const Color(0xFFFDEAE7), AppColors.danger),
      'offer' ||
      'interview' ||
      'pending' => (AppColors.tintOrange, const Color(0xFF865313)),
      'expired' ||
      'withdrawn' ||
      'draft' ||
      'synthetic' => (AppColors.paper2, AppColors.body),
      _ => (AppColors.tintBlue, AppColors.brandBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;
  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: error,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: error ? AppColors.danger : AppColors.brandBlue,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.body),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
