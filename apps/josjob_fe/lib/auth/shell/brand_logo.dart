part of '../auth_page.dart';

class _BrandLogo extends StatelessWidget {
  final bool dark;
  const _BrandLogo({required this.dark});
  @override
  Widget build(BuildContext context) => AppBrand(light: !dark);
}
