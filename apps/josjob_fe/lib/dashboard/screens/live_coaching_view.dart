import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../live/live_call_page.dart';
import '../../live/data/live_models.dart' show LiveRoomMode, ParticipantRole;
import '../../services/live_coaching_api.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../shared/app_form_field.dart';

typedef CoachingAuthorize =
    Future<T> Function<T>(Future<T> Function(String) call);
String coachingTime(DateTime start, DateTime end) {
  String pad(int n) => n.toString().padLeft(2, '0');
  final s = start.toLocal(), e = end.toLocal();
  return '${s.year}-${pad(s.month)}-${pad(s.day)} · ${pad(s.hour)}:${pad(s.minute)}–${pad(e.hour)}:${pad(e.minute)}';
}

class CoachingPage extends StatelessWidget {
  const CoachingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('Coaching')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: const LiveCoachingView(),
        ),
      ),
    ),
  );
}

class LiveCoachingView extends StatefulWidget {
  final LiveCoachingApi? api;
  final CoachingAuthorize? authorize;
  final void Function(CoachingBooking)? onJoin;
  final bool? isAdmin;
  const LiveCoachingView({
    super.key,
    this.api,
    this.authorize,
    this.onJoin,
    this.isAdmin,
  });
  @override
  State<LiveCoachingView> createState() => _LiveCoachingViewState();
}

class _LiveCoachingViewState extends State<LiveCoachingView> {
  late final LiveCoachingApi _api = widget.api ?? LiveCoachingApi();
  final _search = TextEditingController(),
      _name = TextEditingController(),
      _headline = TextEditingController(),
      _bio = TextEditingController(),
      _expertise = TextEditingController(),
      _minutes = TextEditingController(text: '30');
  final _form = GlobalKey<FormState>();
  LiveCoachingData? _data;
  List<CoachProfile> _reviews = [];
  bool _loading = true,
      _working = false,
      _workspace = false,
      _review = false,
      _history = false,
      _dirty = false;
  String? _error;
  int _generation = 0;
  Timer? _timer;
  bool get _admin =>
      widget.isAdmin ?? Session.instance.user?.isSuperuser == true;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading && !_working && !_workspace && !_review) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    for (final c in [_search, _name, _headline, _bio, _expertise, _minutes]) {
      c.dispose();
    }
    if (widget.api == null) {
      _api.close();
    }
    super.dispose();
  }

  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);
  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _auth(_api.fetch);
      final reviews = _admin && _review
          ? await _auth(_api.adminProfiles)
          : <CoachProfile>[];
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _data = data;
        _reviews = reviews;
        _error = null;
      });
      if (!_dirty && data.myProfile != null) {
        final p = data.myProfile!;
        _name.text = p.name;
        _headline.text = p.headline;
        _bio.text = p.bio;
        _expertise.text = p.expertise.join(', ');
        _minutes.text = '${p.minutes}';
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _perform(Future<void> Function(String) call) async {
    setState(() => _working = true);
    try {
      await _auth(call);
      await _load();
      return true;
    } catch (e) {
      _toast(e.toString());
      return false;
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _profile() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final attrs = {
      'display_name': _name.text.trim(),
      'headline': _headline.text.trim(),
      'bio': _bio.text.trim(),
      'expertise': _expertise.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList(),
      'session_minutes': int.parse(_minutes.text),
    };
    if (await _perform((t) => _api.saveProfile(t, attrs))) {
      _dirty = false;
      _toast('Profile saved. New profiles need admin approval.');
    }
  }

  Future<void> _addSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      builder: appFormDialog,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      builder: appFormDialog,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) {
      return;
    }
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (await _perform((t) => _api.createSlot(t, start))) {
      _toast('Availability added.');
    }
  }

  Future<void> _details(CoachProfile coach) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CoachDetails(
        coach: coach,
        own: coach.id == _data?.myProfile?.id,
        book: (id) => _auth((t) => _api.book(t, id)),
      ),
    );
    if (booked == true && mounted) {
      await _load();
      _toast('Your free appointment is confirmed.');
    }
  }

  Future<void> _change(CoachingBooking b, String action) async {
    if (action == 'cancel') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cancel this appointment?'),
          content: const Text(
            'The slot will become available again if it is still in the future.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep appointment'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancel appointment'),
            ),
          ],
        ),
      );
      if (yes != true) {
        return;
      }
    }
    await _perform((t) => _api.changeBooking(t, b.id, action));
  }

  void _join(CoachingBooking b) {
    if (widget.onJoin != null) {
      widget.onJoin!(b);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveCallPage(
          roomId: b.roomId,
          mode: LiveRoomMode.oneOnOne,
          role: b.host ? ParticipantRole.host : ParticipantRole.guest,
          displayName: Session.instance.user?.firstName,
        ),
      ),
    );
  }

  TextStyle _style(
    double size, {
    bool bold = false,
    Color color = AppColors.navy,
  }) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    color: color,
  );
  Widget _card(Widget child, {Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
  Widget _title(String title) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Text(title, style: _style(18, bold: true)),
  );
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('live-coaching'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _review
                      ? 'Review coaches'
                      : _workspace
                      ? 'Coach workspace'
                      : 'Live Coaching',
                  style: _style(26, bold: true),
                ),
                const SizedBox(height: 6),
                Text(
                  'Free one-on-one appointments, independent of courses',
                  style: _style(13, color: AppColors.body),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('refresh-coaching'),
            tooltip: 'Refresh coaching',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _workspace = false;
                _review = false;
              });
            },
            child: const Text('Find a coach'),
          ),
          TextButton(
            key: const ValueKey('coach-workspace'),
            onPressed: () {
              setState(() {
                _workspace = true;
                _review = false;
              });
            },
            child: const Text('Coach workspace'),
          ),
          if (_admin)
            TextButton(
              onPressed: () {
                setState(() {
                  _review = true;
                  _workspace = false;
                });
                _load();
              },
              child: const Text('Review coach profiles'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (_loading)
        _card(const Center(child: CircularProgressIndicator()))
      else if (_error != null)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!),
              TextButton(
                key: const ValueKey('retry-coaching'),
                onPressed: () => _load(),
                child: const Text('Try again'),
              ),
            ],
          ),
        )
      else if (_data != null)
        ...(_review
            ? _reviewContent()
            : _workspace
            ? _workspaceContent(_data!)
            : _directory(_data!)),
    ],
  );
  List<Widget> _directory(LiveCoachingData data) {
    final q = _search.text.trim().toLowerCase();
    final coaches = data.coaches
        .where(
          (c) =>
              q.isEmpty ||
              [
                c.name,
                c.headline,
                ...c.expertise,
              ].any((v) => v.toLowerCase().contains(q)),
        )
        .toList();
    final now = DateTime.now();
    final bookings = data.bookings
        .where(
          (b) => _history
              ? (b.status != 'confirmed' || !b.endsAt.isAfter(now))
              : (b.status == 'confirmed' && b.endsAt.isAfter(now)),
        )
        .toList();
    return [
      if (!data.configured)
        _card(
          Text(
            'Appointment booking is available. Video calls will be enabled when live video is configured.',
            key: const ValueKey('coaching-video-unavailable'),
            style: _style(13, color: AppColors.body),
          ),
        ),
      _title('Your appointments'),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Upcoming'),
            selected: !_history,
            onSelected: (_) => setState(() => _history = false),
          ),
          ChoiceChip(
            label: const Text('History'),
            selected: _history,
            onSelected: (_) => setState(() => _history = true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (bookings.isEmpty)
        _card(
          Text(
            _history
                ? 'No past appointments.'
                : 'No appointments yet. Choose a coach and book an available slot.',
            key: const ValueKey('empty-coaching-bookings'),
            style: _style(13, color: AppColors.body),
          ),
        )
      else
        ...bookings.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.host ? 'With ${b.learnerName}' : b.coachName,
                    style: _style(16, bold: true),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    coachingTime(b.startsAt, b.endsAt),
                    style: _style(13, color: AppColors.body),
                  ),
                  Text(
                    'Free · 1-on-1 · ${b.status}',
                    style: _style(12, color: AppColors.brandBlue),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (b.status == 'confirmed')
                        FilledButton.icon(
                          key: ValueKey('join-booking-${b.id}'),
                          onPressed: b.canJoin && data.configured
                              ? () => _join(b)
                              : null,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Join appointment'),
                        ),
                      if (b.canCancel)
                        TextButton(
                          key: ValueKey('cancel-booking-${b.id}'),
                          onPressed: _working
                              ? null
                              : () => _change(b, 'cancel'),
                          child: const Text('Cancel'),
                        ),
                      if (b.canComplete)
                        TextButton(
                          onPressed: _working
                              ? null
                              : () => _change(b, 'complete'),
                          child: const Text('Mark completed'),
                        ),
                    ],
                  ),
                  if (b.status == 'confirmed' && !b.canJoin)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Call access is available during the scheduled appointment.',
                        style: _style(11, color: AppColors.body),
                      ),
                    ),
                ],
              ),
              key: ValueKey('coaching-booking-${b.id}'),
            ),
          ),
        ),
      _title('Find a coach'),
      Text(
        'Approved coach profiles. No course enrollment is required.',
        style: _style(13, color: AppColors.body),
      ),
      const SizedBox(height: 14),
      AppFormField(
        key: const ValueKey('search-coaches'),
        label: 'Search coaches',
        hint: 'Name or expertise',
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close),
              ),
      ),
      const SizedBox(height: 16),
      if (coaches.isEmpty)
        _card(
          Text(
            data.coaches.isEmpty
                ? 'No approved coaches yet. Coach profiles will appear after approval.'
                : 'No coaches match your search.',
            style: _style(13, color: AppColors.body),
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 2 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final c in coaches)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 16 * (columns - 1)) / columns,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: _style(18, bold: true)),
                          const SizedBox(height: 6),
                          Text(c.headline, style: _style(14)),
                          const SizedBox(height: 8),
                          Text(
                            c.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: _style(13, color: AppColors.body),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in c.expertise)
                                Chip(label: Text(tag)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Free · ${c.minutes} minutes · 1-on-1',
                            style: _style(
                              12,
                              bold: true,
                              color: AppColors.brandBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            key: ValueKey('view-coach-${c.id}'),
                            onPressed: () => _details(c),
                            child: const Text('View profile & availability'),
                          ),
                        ],
                      ),
                      key: ValueKey('coach-profile-${c.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      const SizedBox(height: 16),
      Text(
        'Times are shown in your local timezone.',
        style: _style(11, color: AppColors.body),
      ),
    ];
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int min = 0,
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppFormField(
      label: label,
      hint: hint,
      controller: controller,
      onChanged: (_) => _dirty = true,
      maxLines: lines,
      validator: (v) => (v?.trim().length ?? 0) < min
          ? 'Enter at least $min characters.'
          : null,
    ),
  );
  List<Widget> _workspaceContent(LiveCoachingData data) => [
    _card(
      Text(
        data.myProfile == null
            ? 'Create your coach profile. A platform admin reviews it before it appears publicly.'
            : 'Profile status: ${data.myProfile!.status}',
        key: const ValueKey('coach-profile-status'),
        style: _style(14),
      ),
    ),
    _title('Your profile'),
    _card(
      Theme(
        data: appFormTheme(context),
        child: Form(
          key: _form,
          child: Column(
            children: [
              _field('Display name', _name, min: 2, hint: 'Your public name'),
              _field(
                'Headline',
                _headline,
                min: 3,
                hint: 'How you help learners',
              ),
              _field(
                'About your coaching',
                _bio,
                min: 10,
                lines: 4,
                hint: 'Your experience and coaching approach',
              ),
              _field(
                'Expertise (comma-separated)',
                _expertise,
                hint: 'Career planning, interviews',
              ),
              AppFormField(
                label: 'Session duration in minutes',
                hint: '30',
                helper: '15–120 minutes. All appointments are free.',
                controller: _minutes,
                onChanged: (_) => _dirty = true,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 15 || n > 120
                      ? 'Choose 15–120 minutes.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('save-coach-profile'),
                onPressed: _working ? null : _profile,
                child: const Text('Save coach profile'),
              ),
            ],
          ),
        ),
      ),
    ),
    if (data.myProfile != null) ...[
      _title('Your availability'),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const ValueKey('add-coaching-slot'),
          onPressed: _working ? null : _addSlot,
          icon: const Icon(Icons.add),
          label: const Text('Add availability'),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Choose a date and time in your local timezone. Booked slots must be cancelled through the appointment first.',
        style: _style(12, color: AppColors.body),
      ),
      const SizedBox(height: 12),
      if (data.mySlots.isEmpty)
        _card(const Text('No future availability slots.'))
      else
        ...data.mySlots.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(
              Row(
                children: [
                  Expanded(child: Text(coachingTime(s.startsAt, s.endsAt))),
                  const SizedBox(width: 8),
                  if (s.booked)
                    const Text('Booked')
                  else
                    IconButton(
                      tooltip: 'Remove availability',
                      onPressed: _working
                          ? null
                          : () => _perform((t) => _api.closeSlot(t, s.id)),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  ];
  List<Widget> _reviewContent() => [
    _title('Coach publication'),
    if (_reviews.isEmpty)
      _card(const Text('No coach profiles to review.'))
    else
      ..._reviews.map(
        (p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: _style(17, bold: true)),
                Text(p.headline),
                const SizedBox(height: 8),
                Text(p.bio),
                Text('Status: ${p.status}'),
                Wrap(
                  spacing: 8,
                  children: [
                    if (p.status != 'approved')
                      FilledButton(
                        onPressed: _working
                            ? null
                            : () => _perform(
                                (t) => _api.review(t, p.id, 'approved'),
                              ),
                        child: const Text('Approve'),
                      ),
                    if (p.status == 'approved')
                      TextButton(
                        onPressed: _working
                            ? null
                            : () => _perform(
                                (t) => _api.review(t, p.id, 'suspended'),
                              ),
                        child: const Text('Suspend'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
  ];
}

class _CoachDetails extends StatefulWidget {
  final CoachProfile coach;
  final bool own;
  final Future<void> Function(String) book;
  const _CoachDetails({
    required this.coach,
    required this.own,
    required this.book,
  });
  @override
  State<_CoachDetails> createState() => _CoachDetailsState();
}

class _CoachDetailsState extends State<_CoachDetails> {
  String? _busy, _error;
  Future<void> _book(CoachSlot slot) async {
    setState(() {
      _busy = slot.id;
      _error = null;
    });
    try {
      await widget.book(slot.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.coach.name,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close profile',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(widget.coach.headline),
          const SizedBox(height: 16),
          Text(widget.coach.bio),
          const SizedBox(height: 16),
          Text('Free · ${widget.coach.minutes} minutes · 1-on-1'),
          const SizedBox(height: 20),
          const Text('Available appointments (your local timezone)'),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (widget.own)
            const Text('This is your public coach profile.')
          else if (widget.coach.slots.isEmpty)
            const Text('No available slots yet. Check back later.')
          else
            ...widget.coach.slots.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(coachingTime(s.startsAt, s.endsAt)),
                        FilledButton(
                          key: ValueKey('book-slot-${s.id}'),
                          onPressed: _busy != null ? null : () => _book(s),
                          child: Text(
                            _busy == s.id
                                ? 'Booking…'
                                : 'Book free appointment',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
