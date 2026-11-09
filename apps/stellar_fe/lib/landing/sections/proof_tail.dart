part of '../landing_page_ascent.dart';

// -------------------------------------------------------------------------
// Proof tail
// -------------------------------------------------------------------------
class _ProofTail extends StatelessWidget {
  final GlobalKey summitKey;
  const _ProofTail({required this.summitKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const _MissionBand(),
        const _TestimonialsSection(),
        const _PartnersSection(),
        const _MomentsSection(),
        const _FaqSection(),
        _SummitSection(key: summitKey),
      ],
    );
  }
}
