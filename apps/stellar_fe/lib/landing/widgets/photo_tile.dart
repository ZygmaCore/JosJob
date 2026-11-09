part of '../landing_page_ascent.dart';

class _PhotoTile extends StatelessWidget {
  final String caption;
  const _PhotoTile({required this.caption});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Training: $caption',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 1.3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFDBE6F2), Color(0xFFC3D3E6)],
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.groups_2_outlined,
                  size: 44,
                  color: Colors.white70,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(
                  caption,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
