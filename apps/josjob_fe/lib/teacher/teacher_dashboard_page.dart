import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing/landing_page_ascent.dart' show JosjobLandingPage;
import '../live/live_call_page.dart' show LiveCallPage;
import '../live/data/live_models.dart'
    show LiveRoomMode, ParticipantRole, classRoomId;
import '../services/classes_api.dart';
import '../services/documents_api.dart';
import '../services/auth_api.dart' show AuthException;
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'upload_document_page.dart';

// =========================================================================
// JosJob — Teacher dashboard (route '/dashboard' for teachers)
//
// The landing surface for an invited teacher. It is document-centric: a
// welcome header, a "Documents" section that lists the teacher's documents
// (via GET /api/documents), and a prominent "Upload document" action that
// opens the upload flow (video / PDF / DOC, not tied to any course).
//
// A dedicated, simpler surface than the consumer DashboardPage (Learn|Jobs) —
// teachers manage content, so the shell stays focused rather than reusing the
// role-adaptive consumer shell.
// =========================================================================

class TeacherDashboardPage extends StatefulWidget {
  final String? firstName;
  const TeacherDashboardPage({super.key, this.firstName});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final DocumentsApi _api = DocumentsApi();
  final ClassesApi _classesApi = ClassesApi();

  bool _loading = true;
  String? _error;
  List<DocItem> _docs = const [];

  // Classes this teacher instructs — a live session runs for one of them
  // (room `class:<id>`, gated by enrollment server-side).
  bool _classesLoading = true;
  String? _classesError;
  List<LiveClass> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadClasses();
  }

  @override
  void dispose() {
    _api.close();
    _classesApi.close();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _classesLoading = true;
      _classesError = null;
    });
    try {
      final classes = await Session.instance.runAuthed(
        (t) => _classesApi.listMyClasses(t),
      );
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classesLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _classesError = e.message;
        _classesLoading = false;
      });
    } on ClassApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _classesError = e.message;
        _classesLoading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await Session.instance.runAuthed(
        (t) => _api.listDocuments(t),
      );
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on DocApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openUpload() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const UploadDocumentPage()));
    if (saved == true) _load();
  }

  /// Start a live session (Cloudflare Realtime SFU) for one of the teacher's
  /// classes, as the host. Picks the class (auto if only one), then opens the
  /// call in room `class:<id>` — the backend admits only the instructor + the
  /// class's enrolled students.
  Future<void> _startLive(LiveRoomMode mode) async {
    if (_classesLoading) {
      _snack('Loading your classes — one moment…');
      return;
    }
    if (_classesError != null) {
      _snack(_classesError!);
      return;
    }
    if (_classes.isEmpty) {
      _snack(
        "You don't teach any classes yet. An admin assigns you as a class instructor.",
      );
      return;
    }

    final selected = _classes.length == 1 ? _classes.first : await _pickClass();
    if (selected == null || !mounted) return;

    final name = Session.instance.user?.firstName;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveCallPage(
          roomId: classRoomId(selected.id, mode),
          mode: mode,
          role: ParticipantRole.host,
          displayName: (name != null && name.isNotEmpty) ? name : null,
        ),
      ),
    );
  }

  /// Bottom sheet to choose which class the session runs for (>1 class).
  Future<LiveClass?> _pickClass() {
    return showModalBottomSheet<LiveClass>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Choose a class',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            for (final c in _classes)
              ListTile(
                leading: const Icon(
                  Icons.class_outlined,
                  color: AppColors.iconBlue,
                ),
                title: Text(
                  c.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: c.courseTitle == null
                    ? null
                    : Text(
                        c.courseTitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.body,
                        ),
                      ),
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          content: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  /// One-line hint under the live-sessions header describing what "Start" does.
  String _liveSubtitle() {
    if (_classesLoading) return 'Loading your classes…';
    if (_classesError != null) return _classesError!;
    if (_classes.isEmpty) {
      return 'You have no classes yet — an admin assigns you as a class instructor.';
    }
    final n = _classes.length;
    return n == 1
        ? 'Starts a session for “${_classes.first.title}”. Only enrolled students can join.'
        : 'Pick one of your $n classes to start it for. Only enrolled students can join.';
  }

  Future<void> _signOut() async {
    await Session.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JosjobLandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.firstName ?? Session.instance.user?.firstName ?? '')
        .trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 20,
        title: Row(
          children: [
            _Logo(),
            const SizedBox(width: 10),
            Text(
              'Teacher workspace',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              'Sign out',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.body),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.brandBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Bp.maxContent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    name: name,
                    count: _docs.length,
                    onUpload: _openUpload,
                  ),
                  const SizedBox(height: 24),
                  _LiveSessionsSection(
                    onStart: _startLive,
                    subtitle: _liveSubtitle(),
                  ),
                  const SizedBox(height: 24),
                  _DocumentsSection(
                    loading: _loading,
                    error: _error,
                    docs: _docs,
                    onUpload: _openUpload,
                    onRetry: _load,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.heroBlue, AppColors.brandBlue],
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.school_rounded, size: 18, color: Colors.white),
  );
}

class _Header extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onUpload;
  const _Header({
    required this.name,
    required this.count,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 640;
    final greeting = name.isEmpty ? 'Welcome' : 'Welcome, $name';

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tintBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Teacher',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          greeting,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          count == 0
              ? 'Upload your teaching materials — videos, PDFs and documents.'
              : 'You have $count document${count == 1 ? '' : 's'} in your library.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
      ],
    );

    final button = _PrimaryButton(
      label: 'Upload document',
      icon: Icons.cloud_upload_outlined,
      onTap: onUpload,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 18), button],
            ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<DocItem> docs;
  final VoidCallback onUpload;
  final VoidCallback onRetry;
  const _DocumentsSection({
    required this.loading,
    required this.error,
    required this.docs,
    required this.onUpload,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_copy_outlined,
                  size: 20,
                  color: AppColors.iconBlue,
                ),
                const SizedBox(width: 10),
                Text(
                  'Documents',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                if (docs.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/documents'),
                    child: Text(
                      'Manage all',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
          ),
        ),
      );
    }
    if (error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFD64B4B),
        title: "Couldn't load documents",
        body: error!,
        action: _SecondaryButton(label: 'Try again', onTap: onRetry),
      );
    }
    if (docs.isEmpty) {
      return _Message(
        icon: Icons.upload_file_outlined,
        color: AppColors.iconBlue,
        title: 'No documents yet',
        body: 'Upload a video, PDF or Word document to build your library.',
        action: _SecondaryButton(label: 'Upload a document', onTap: onUpload),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < docs.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          _DocRow(doc: docs[i]),
        ],
      ],
    );
  }
}

// A single live-session type a teacher can start.
class _LiveOption {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final LiveRoomMode mode;
  const _LiveOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.mode,
  });
}

class _LiveSessionsSection extends StatelessWidget {
  final void Function(LiveRoomMode mode) onStart;
  final String subtitle;
  const _LiveSessionsSection({required this.onStart, required this.subtitle});

  static const List<_LiveOption> _options = [
    _LiveOption(
      label: 'Classroom',
      subtitle: 'Broadcast a lesson — you present, students watch.',
      icon: Icons.cast_for_education_outlined,
      tint: AppColors.tintBlue,
      iconColor: AppColors.iconBlue,
      mode: LiveRoomMode.classroom,
    ),
    _LiveOption(
      label: '1-on-1 coaching',
      subtitle: 'A private two-way session with one learner.',
      icon: Icons.person_outline,
      tint: AppColors.tintGreen,
      iconColor: AppColors.iconGreen,
      mode: LiveRoomMode.oneOnOne,
    ),
    _LiveOption(
      label: 'Conference call',
      subtitle: 'A group room where everyone can talk and share.',
      icon: Icons.groups_outlined,
      tint: AppColors.tintOrange,
      iconColor: AppColors.iconOrange,
      mode: LiveRoomMode.coaching,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
                    const SizedBox(width: 10),
                    Text(
                      'Start a live session',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.body,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 640;
                final cards = [
                  for (final o in _options)
                    _LiveOptionCard(option: o, onTap: () => onStart(o.mode)),
                ];
                if (wide) {
                  // IntrinsicHeight gives the Row a bounded height so the
                  // stretched cards share the tallest card's height.
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      cards[i],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOptionCard extends StatelessWidget {
  final _LiveOption option;
  final VoidCallback onTap;
  const _LiveOptionCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: option.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, size: 22, color: option.iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                option.label,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.body,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Start',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: option.iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: option.iconColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final DocItem doc;
  const _DocRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: doc.isVideo ? AppColors.tintOrange : AppColors.tintBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              doc.isVideo
                  ? Icons.play_circle_outline_rounded
                  : Icons.description_outlined,
              size: 22,
              color: doc.isVideo ? AppColors.iconOrange : AppColors.iconBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(doc),
                  maxLines: 1,
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
          _RelationshipChip(relationship: doc.relationship),
        ],
      ),
    );
  }

  String _subtitle(DocItem d) {
    final kind = d.isVideo
        ? 'Video'
        : (d.mimeType ?? 'File').split('/').last.toUpperCase();
    final desc = (d.description ?? '').trim();
    return desc.isEmpty ? kind : '$kind · $desc';
  }
}

class _RelationshipChip extends StatelessWidget {
  final String relationship;
  const _RelationshipChip({required this.relationship});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (relationship) {
      'owner' => ('Yours', AppColors.tintGreen, AppColors.iconGreen),
      'org' => ('Org', AppColors.tintBlue, AppColors.brandBlue),
      'admin' => ('Admin', AppColors.tintBlue, AppColors.brandBlue),
      _ => ('Shared', AppColors.tintOrange, AppColors.iconOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget action;
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 46, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: AppColors.body,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          action,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brandBlue,
        side: const BorderSide(color: AppColors.brandBlue),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
