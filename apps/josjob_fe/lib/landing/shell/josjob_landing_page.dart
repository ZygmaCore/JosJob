part of '../landing_page_ascent.dart';

// =========================================================================
// Page
// =========================================================================
class JosjobLandingPage extends StatefulWidget {
  const JosjobLandingPage({super.key});

  @override
  State<JosjobLandingPage> createState() => _JosjobLandingPageState();
}

class _JosjobLandingPageState extends State<JosjobLandingPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = ScrollController();
  final _summitKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: AppColors.board,
          secondary: AppColors.primaryDeep,
          surface: AppColors.cotton,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryDeep, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.paper,
        endDrawer: _isMobile(context)
            ? _MobileDrawer(
                onCta: () => Navigator.of(context).pushNamed('/register'),
                onLogin: () => Navigator.of(context).pushNamed('/login'),
                onHowItWorks: () => _jumpTo(_summitKey),
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
                    onHowItWorks: () => _jumpTo(_summitKey),
                  ),
                  const _ProductsBand(),
                  _RankingPreview(
                    onBrowse: () =>
                        Navigator.of(context).pushNamed('/register'),
                    onUpload: () =>
                        Navigator.of(context).pushNamed('/register'),
                  ),
                  _HowItWorks(key: _summitKey),
                  _FinalCta(
                    onGetStarted: () =>
                        Navigator.of(context).pushNamed('/register'),
                  ),
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
                onHowItWorks: () => _jumpTo(_summitKey),
                onRegister: () => Navigator.of(context).pushNamed('/register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
