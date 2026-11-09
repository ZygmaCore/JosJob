part of '../landing_page_ascent.dart';

// =========================================================================
// Page
// =========================================================================
class StellarLandingPage extends StatefulWidget {
  const StellarLandingPage({super.key});

  @override
  State<StellarLandingPage> createState() => _StellarLandingPageState();
}

class _StellarLandingPageState extends State<StellarLandingPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = ScrollController();
  final _fraction = ValueNotifier<double>(0);
  final List<GlobalKey> _milestoneKeys = List.generate(
    _milestoneCount,
    (_) => GlobalKey(),
  );
  final _summitKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final max = _controller.position.maxScrollExtent;
    final f = max <= 0 ? 0.0 : (_controller.offset / max).clamp(0.0, 1.0);
    if ((f - _fraction.value).abs() > 0.002) _fraction.value = f;
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _fraction.dispose();
    super.dispose();
  }

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: _reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      endDrawer: _isMobile(context)
          ? _MobileDrawer(
              onCta: () => Navigator.of(context).pushNamed('/register'),
              onLogin: () => Navigator.of(context).pushNamed('/login'),
            )
          : null,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            child: Column(
              children: [
                const SizedBox(height: Bp.navHeight),
                _Hero(
                  onCta: () => Navigator.of(context).pushNamed('/register'),
                  onHowItWorks: () => _jumpTo(_milestoneKeys[4]),
                ),
                const _ProductsBand(),
                _SpineTrack(fraction: _fraction, milestoneKeys: _milestoneKeys),
                _ProofTail(summitKey: _summitKey),
                const _Footer(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopNav(
              onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              onLogin: () => Navigator.of(context).pushNamed('/login'),
            ),
          ),
        ],
      ),
    );
  }
}
