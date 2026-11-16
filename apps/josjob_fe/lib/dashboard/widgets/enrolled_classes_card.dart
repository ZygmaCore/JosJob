part of '../dashboard_page.dart';

// =========================================================================
// Enrolled classes → join a live session. Replaces the old demo "Start a live
// session" card on the Live Coaching screen. Loads GET /api/me/enrollments; each
// enrolled class can join a Classroom (view-only broadcast), 1-on-1, or
// Conference session in room `class:<id>` — the backend admits only the class's
// instructor + its enrolled students, so a learner sees join only for classes
// they're actually enrolled in.
// =========================================================================
class _EnrolledClassesCard extends StatefulWidget {
  const _EnrolledClassesCard();

  @override
  State<_EnrolledClassesCard> createState() => _EnrolledClassesCardState();
}

class _EnrolledClassesCardState extends State<_EnrolledClassesCard> {
  final ClassesApi _api = ClassesApi();

  bool _loading = true;
  String? _error;
  List<LiveClass> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await Session.instance.runAuthed(
        (t) => _api.listMyEnrollments(t),
      );
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on ClassApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _join(LiveClass c, LiveRoomMode mode) => _startLive(
    context,
    mode: mode,
    role: ParticipantRole.guest,
    room: classRoomId(c.id, mode),
  );

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.videocam_rounded,
                size: 20,
                color: AppColors.iconBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Your live classes',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Join a live session for a class you're enrolled in.",
            style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
          ),
          const SizedBox(height: 16),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
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
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.body),
          ),
          const SizedBox(height: 12),
          _PillButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            variant: _PillVariant.ghost,
            onPressed: _load,
          ),
        ],
      );
    }
    if (_classes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You're not enrolled in any classes yet. Enroll from the course "
            'catalog to join its live sessions.',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: AppColors.body,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _PillButton(
            label: 'Browse catalog',
            icon: Icons.explore_outlined,
            variant: _PillVariant.ghost,
            onPressed: () => _explore(context),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _classes.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ClassJoinRow(liveClass: _classes[i], onJoin: _join),
        ],
      ],
    );
  }
}

// One enrolled class with its three join actions.
class _ClassJoinRow extends StatelessWidget {
  final LiveClass liveClass;
  final void Function(LiveClass, LiveRoomMode) onJoin;
  const _ClassJoinRow({required this.liveClass, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            liveClass.title,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (liveClass.courseTitle != null) ...[
            const SizedBox(height: 2),
            Text(
              liveClass.courseTitle!,
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.body),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillButton(
                label: 'Classroom',
                icon: Icons.cast_for_education_outlined,
                variant: _PillVariant.tint,
                onPressed: () => onJoin(liveClass, LiveRoomMode.classroom),
              ),
              _PillButton(
                label: '1-on-1',
                icon: Icons.person_outline,
                variant: _PillVariant.tint,
                onPressed: () => onJoin(liveClass, LiveRoomMode.oneOnOne),
              ),
              _PillButton(
                label: 'Conference',
                icon: Icons.groups_outlined,
                variant: _PillVariant.tint,
                onPressed: () => onJoin(liveClass, LiveRoomMode.coaching),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
