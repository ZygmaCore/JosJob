part of '../dashboard_page.dart';

// =========================================================================
// Circular initials avatar. Decorative by default (name is conveyed by the
// adjacent label), so it is hidden from the semantics tree.
// =========================================================================
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;
  const _Avatar({required this.name, this.size = 40, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: hasImage ? Clip.antiAlias : Clip.none,
        decoration: const BoxDecoration(
          color: AppColors.tintBlue,
          shape: BoxShape.circle,
        ),
        child: hasImage
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Google avatar failed to load → fall back to initials.
                errorBuilder: (_, _, _) => _initialsLabel(),
              )
            : _initialsLabel(),
      ),
    );
  }

  Widget _initialsLabel() => Text(
    _initials(name),
    style: GoogleFonts.poppins(
      fontSize: size * 0.36,
      fontWeight: FontWeight.w700,
      color: AppColors.brandBlue,
    ),
  );
}
