part of '../explore_page.dart';

// =========================================================================
// Course preview — a modal bottom sheet for one course: a gradient hero, its
// field(s), category, description, and the list of CLASSES (sessions) the
// student can enrol in. Enrolment is real: it fetches the course detail from
// GET /api/catalog/courses/:id and POSTs to /api/classes/:id/enroll.
// =========================================================================
class _CoursePreviewSheet extends StatefulWidget {
  final _Course course;
  final bool initialSaved;
  final ValueChanged<String> onToggleSaved;
  const _CoursePreviewSheet({
    required this.course,
    required this.initialSaved,
    required this.onToggleSaved,
  });

  @override
  State<_CoursePreviewSheet> createState() => _CoursePreviewSheetState();
}

class _CoursePreviewSheetState extends State<_CoursePreviewSheet> {
  final CoursesApi _api = CoursesApi();

  late bool _saved = widget.initialSaved;

  CourseDetail? _detail;
  bool _loadingDetail = true;
  String? _detailError;

  final Set<String> _enrolledClassIds = {};
  String? _busyClassId; // the class currently enrolling / leaving

  @override
  void initState() {
    super.initState();
    _loadDetail(initial: true);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadDetail({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loadingDetail = true;
        _detailError = null;
      });
    }
    try {
      final d = await Session.instance.runAuthed(
        (t) => _api.getCourse(t, widget.course.id),
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _enrolledClassIds
          ..clear()
          ..addAll([
            for (final c in d.classes)
              if (c.enrolled) c.id,
          ]);
        _loadingDetail = false;
      });
    } on CourseApiException catch (e) {
      if (mounted && initial) {
        setState(() {
          _detailError = e.message;
          _loadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted && initial) {
        setState(() {
          _detailError = 'Something went wrong. Please try again.';
          _loadingDetail = false;
        });
      }
    }
  }

  void _toggleSaved() {
    setState(() => _saved = !_saved);
    widget.onToggleSaved(widget.course.id);
  }

  Future<void> _enroll(CourseClass c) async {
    setState(() => _busyClassId = c.id);
    try {
      final start = await Session.instance.runAuthed(
        (t) => _api.startEnroll(t, c.id),
      );
      if (!mounted) return;

      // FREE course: the server already enrolled us.
      if (start.free) {
        setState(() => _enrolledClassIds.add(c.id));
        _soon(context, "You're enrolled in this session.");
        _loadDetail();
        return;
      }

      // PAID: collect a card in-app, confirm the Stripe payment, then have the
      // server verify it and grant the enrolment.
      final paid = await _payWithCard(start);
      if (!paid || !mounted) return;

      await Session.instance.runAuthed(
        (t) => _api.confirmEnroll(t, c.id, start.paymentIntentId!),
      );
      if (!mounted) return;
      setState(() => _enrolledClassIds.add(c.id));
      _soon(context, "Payment received — you're enrolled!");
      _loadDetail();
    } on CourseApiException catch (e) {
      if (mounted) _soon(context, e.message);
    } catch (_) {
      if (mounted) _soon(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busyClassId = null);
    }
  }

  // Present an in-app Stripe card sheet for [start]; true if the payment
  // succeeded. Card errors are surfaced inside the sheet.
  Future<bool> _payWithCard(EnrollStart start) async {
    final pk = start.publishableKey;
    final secret = start.clientSecret;
    if (pk == null || pk.isEmpty || secret == null || secret.isEmpty) {
      _soon(context, 'Payments are not set up on the server yet.');
      return false;
    }

    Stripe.publishableKey = pk;
    try {
      await Stripe.instance.applySettings();
    } catch (_) {}
    if (!mounted) return false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _CardPaymentSheet(
        clientSecret: secret,
        amountLabel: start.amountLabel ?? '',
        courseTitle: widget.course.title,
      ),
    );
    return ok == true;
  }

  Future<void> _leave(CourseClass c) async {
    setState(() => _busyClassId = c.id);
    try {
      await Session.instance.runAuthed((t) => _api.unenroll(t, c.id));
      if (!mounted) return;
      setState(() => _enrolledClassIds.remove(c.id));
      _soon(context, 'You left this session.');
      _loadDetail();
    } on CourseApiException catch (e) {
      if (mounted) _soon(context, e.message);
    } catch (_) {
      if (mounted) _soon(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busyClassId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final visual = _industryVisual(c.primaryIndustry);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const _SheetGrabber(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _hero(c, visual),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.industries.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in c.industries)
                                  _TagPill(
                                    _industryVisual(name).short,
                                    fg: _industryVisual(name).iconColor,
                                    bg: _industryVisual(name).tint,
                                  ),
                              ],
                            ),
                          const SizedBox(height: 14),
                          Text(
                            c.title,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          if (c.section != null) ...[
                            const SizedBox(height: 12),
                            _metaItem(Icons.category_outlined, c.section!),
                          ],
                          const SizedBox(height: 8),
                          _metaItem(
                            Icons.sell_outlined,
                            c.isFree ? 'Free' : (c.priceLabel ?? ''),
                          ),
                          if (c.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 22),
                            _section('About this course'),
                            const SizedBox(height: 10),
                            Text(c.summary, style: _lead(context)),
                          ],
                          const SizedBox(height: 26),
                          _section('Sessions'),
                          const SizedBox(height: 12),
                          _sessions(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Sessions (classes) + enrol --------------------------------------
  Widget _sessions() {
    if (_loadingDetail) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    if (_detailError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_detailError!, style: _lead(context).copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          _PillButton(
            'Try again',
            kind: _BtnKind.ghost,
            trailing: Icons.refresh,
            onPressed: () => _loadDetail(initial: true),
          ),
        ],
      );
    }
    final classes = _detail?.classes ?? const [];
    if (classes.isEmpty) {
      return _infoBox(
        Icons.event_busy_outlined,
        'No sessions scheduled yet — check back soon.',
      );
    }
    return Column(children: [for (final c in classes) _classRow(c)]);
  }

  Widget _classRow(CourseClass c) {
    final enrolled = _enrolledClassIds.contains(c.id);
    final busy = _busyClassId == c.id;
    final title = c.title.isEmpty ? 'Session' : c.title;

    final subtitleBits = <String>[
      c.scheduleLabel,
      if (c.seatsLeft != null)
        (c.isFull ? 'Full' : '${c.seatsLeft} seats left'),
      if (c.instructorName != null) 'with ${c.instructorName}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enrolled ? AppColors.iconGreen : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.tintBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_outlined,
              color: AppColors.iconBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleBits.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _classAction(c, enrolled: enrolled, busy: busy),
        ],
      ),
    );
  }

  Widget _classAction(
    CourseClass c, {
    required bool enrolled,
    required bool busy,
  }) {
    if (busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
        ),
      );
    }
    if (enrolled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.iconGreen,
              ),
              const SizedBox(width: 5),
              Text(
                'Enrolled',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.iconGreen,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _leave(c),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Leave',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.body,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (c.isFull) {
      return Text(
        'Full',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.body,
        ),
      );
    }
    final label = widget.course.isFree
        ? 'Enrol'
        : 'Enrol · ${widget.course.priceLabel}';
    return _PillButton(
      label,
      kind: _BtnKind.dense,
      onPressed: () => _enroll(c),
    );
  }

  Widget _infoBox(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.iconBlue),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: _lead(context).copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  // ---- Hero band --------------------------------------------------------
  Widget _hero(_Course c, _IndustryVisual visual) {
    return SizedBox(
      height: 176,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      visual.tint,
                      visual.gradEnd.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -12,
              bottom: -18,
              child: Icon(
                visual.icon,
                size: 150,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(visual.icon, color: visual.iconColor, size: 28),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Row(
                children: [
                  _circleButton(
                    icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                    color: _saved ? AppColors.brandBlue : AppColors.navy,
                    tooltip: _saved ? 'Remove from saved' : 'Save course',
                    onTap: _toggleSaved,
                  ),
                  const SizedBox(width: 4),
                  _circleButton(
                    icon: Icons.close,
                    color: AppColors.navy,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (c.section != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Flexible(
                      child: _BandBadge(
                        icon: Icons.category_outlined,
                        label: c.section!,
                        bg: AppColors.surface,
                        fg: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        minimumSize: const Size(40, 40),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.body),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

// =========================================================================
// In-app Stripe card entry (Stripe Elements iframe on web). Confirms the
// PaymentIntent with the entered card and pops `true` on success. Card errors
// are surfaced via a snackbar; the caller then finalises the enrolment.
// =========================================================================
class _CardPaymentSheet extends StatefulWidget {
  final String clientSecret;
  final String amountLabel;
  final String courseTitle;
  const _CardPaymentSheet({
    required this.clientSecret,
    required this.amountLabel,
    required this.courseTitle,
  });

  @override
  State<_CardPaymentSheet> createState() => _CardPaymentSheetState();
}

class _CardPaymentSheetState extends State<_CardPaymentSheet> {
  final CardEditController _cardCtrl = CardEditController();
  bool _paying = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final intent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
        data: PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
      );
      if (!mounted) return;
      if (intent.status == PaymentIntentsStatus.Succeeded) {
        Navigator.of(context).pop(true);
      } else {
        _soon(context, 'Payment ${intent.status.name}. Please try again.');
        setState(() => _paying = false);
      }
    } on StripeException catch (e) {
      if (mounted) {
        _soon(context, e.error.localizedMessage ?? 'Payment failed.');
        setState(() => _paying = false);
      }
    } catch (_) {
      if (mounted) {
        _soon(context, 'Payment failed. Please try again.');
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pay for ${widget.courseTitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _paying
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: AppColors.ink),
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter your card to complete enrolment.',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: AppColors.body,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(height: 56, child: CardField(controller: _cardCtrl)),
                  const SizedBox(height: 14),
                  _payButton(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: AppColors.body,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Secured by Stripe',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payButton() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.brandBlue,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _paying ? null : _pay,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: _paying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    widget.amountLabel.isEmpty
                        ? 'Pay now'
                        : 'Pay ${widget.amountLabel}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The little drag handle at the top of a bottom sheet.
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }
}
