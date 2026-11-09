import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session.dart';
import '../services/vod_document_api.dart';
import '../theme/app_theme.dart';

// =========================================================================
// ATVETI STELLAR — VOD upload (as a Document, NOT a lecture)
//
// End-to-end "add a VOD" flow, reached via route '/vod/document':
//   1. name the video (title) + optional description,
//   2. choose a video file (file_picker, in-memory bytes),
//   3. POST /api/vod/documents/upload-url -> a Cloudflare direct-upload URL,
//   4. upload the bytes straight to Cloudflare (never through our backend),
//   5. POST /api/vod/documents -> persist it as a StellarDoc.Document
//      (mime_type video, course_id null — a standalone VOD "used later"),
//   6. poll GET /api/vod/documents/:uid/status until it's `ready`.
//
// A standalone library (not a `part` of vod_page.dart) because it needs its
// own file_picker import. Requires a signed-in session for the write calls.
// =========================================================================

const Color _danger = Color(0xFFD64B4B);

// Map a picked file's extension to a video mime_type for the Document.
String _mimeForExtension(String? ext) {
  switch ((ext ?? '').toLowerCase()) {
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'avi':
      return 'video/x-msvideo';
    case 'm4v':
      return 'video/x-m4v';
    case 'mp4':
    default:
      return 'video/mp4';
  }
}

class VodDocumentUploadPage extends StatefulWidget {
  const VodDocumentUploadPage({super.key});

  @override
  State<VodDocumentUploadPage> createState() => _VodDocumentUploadPageState();
}

enum _Phase { form, working, done, failed }

class _VodDocumentUploadPageState extends State<VodDocumentUploadPage> {
  final VodDocumentApi _api = VodDocumentApi();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  PlatformFile? _file;

  _Phase _phase = _Phase.form;
  String _status = '';
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _file = result.files.single);
  }

  bool get _canUpload =>
      _titleCtrl.text.trim().isNotEmpty && _file?.bytes != null;

  Future<void> _startUpload() async {
    final token = Session.instance.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _phase = _Phase.failed;
        _error = 'Please sign in to upload a video.';
      });
      return;
    }
    final file = _file;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      setState(() {
        _phase = _Phase.failed;
        _error = "Couldn't read the selected file. Please choose it again.";
      });
      return;
    }

    setState(() {
      _phase = _Phase.working;
      _error = null;
    });
    try {
      // 1. Mint the one-time Cloudflare upload URL.
      setState(() => _status = 'Preparing upload…');
      final ticket = await _api.requestUploadUrl(token);

      // 2. Push the bytes straight to Cloudflare.
      if (!mounted) return;
      setState(() => _status = 'Uploading “${file.name}”…');
      await _api.uploadToCloudflare(
        ticket.uploadUrl,
        bytes,
        filename: file.name,
        contentType: _mimeForExtension(file.extension),
      );

      // 3. Persist the VOD as a Document. Once this returns the VOD IS saved —
      //    nothing past this point may report the upload as "failed".
      if (!mounted) return;
      setState(() => _status = 'Saving video…');
      await _api.createDocument(
        token,
        uid: ticket.uid,
        title: _titleCtrl.text.trim(),
        mimeType: _mimeForExtension(file.extension),
        description: _descCtrl.text.trim(),
      );

      // 4. Poll until Cloudflare finishes transcoding (best-effort). The
      //    Document already exists, so ANY poll outcome — ready, timeout,
      //    transcode error, or an expired session — lands on the "saved"
      //    screen, never the "failed / start over" one (which would wrongly
      //    invite a duplicate upload).
      bool ready = false;
      try {
        ready = await _pollUntilReady(token, ticket.uid);
      } on VodDocException {
        ready = false;
      }
      if (!mounted) return;
      setState(() {
        _ready = ready;
        _phase = _Phase.done;
      });
    } on VodDocException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e.message;
      });
    }
  }

  // Poll /status every 3s (~2 min budget). Returns true once `ready`; false on
  // timeout (still processing). A `error` state surfaces as a VodDocException;
  // transient refresh errors are retried. The Document already exists either way.
  Future<bool> _pollUntilReady(String token, String uid) async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      VodDocStatus s;
      try {
        s = await _api.fetchStatus(token, uid);
      } on VodDocException catch (e) {
        if (e.statusCode == 401) rethrow;
        continue; // transient (e.g. Cloudflare still ingesting) — retry
      }
      if (!mounted) return false;
      setState(() => _status = 'Processing video… (${s.state})');
      if (s.isReady) return true;
      if (s.isFailed) {
        throw const VodDocException(
          'The video failed to process on the server. Please try another file.',
        );
      }
    }
    return false;
  }

  void _reset() {
    setState(() {
      _phase = _Phase.form;
      _status = '';
      _error = null;
      _ready = false;
      _file = null;
      _titleCtrl.clear();
      _descCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Upload a video',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (!Session.instance.isSignedIn) return const _SignInPrompt();
    switch (_phase) {
      case _Phase.working:
        return _WorkingCard(status: _status);
      case _Phase.done:
        return _DoneCard(ready: _ready, onAnother: _reset);
      case _Phase.failed:
        return _FailedCard(
          message: _error ?? 'Something went wrong.',
          onRetry: _reset,
        );
      case _Phase.form:
        return _form();
    }
  }

  Widget _form() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Video title'),
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(hint: 'e.g. Welcome & course intro'),
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
            ),

            const SizedBox(height: 18),
            const _FieldLabel('Description (optional)'),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: _fieldDecoration(hint: 'What is this video about?'),
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
            ),

            const SizedBox(height: 18),
            const _FieldLabel('Video file'),
            _FilePickTile(file: _file, onPick: _pickFile),

            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Upload video',
              icon: Icons.cloud_upload_outlined,
              enabled: _canUpload,
              onTap: _startUpload,
            ),
            const SizedBox(height: 10),
            Text(
              'The file is uploaded directly to the video service, transcoded '
              'to HLS, and saved to your video library for use later.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.body,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- shared field chrome -------------------------------------------------

InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.body),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  filled: true,
  fillColor: AppColors.bg,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
  ),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
);

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
  );
}

// The "choose a file" affordance — shows the picked file's name + size once set.
class _FilePickTile extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onPick;
  const _FilePickTile({required this.file, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final f = file;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: f == null ? AppColors.border : AppColors.brandBlue,
          ),
        ),
        child: Row(
          children: [
            Icon(
              f == null
                  ? Icons.video_file_outlined
                  : Icons.check_circle_outline_rounded,
              color: f == null ? AppColors.body : AppColors.iconGreen,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                f == null ? 'Choose a video file' : f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: f == null ? AppColors.body : AppColors.ink,
                  fontWeight: f == null ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              f == null ? 'Browse' : _fmtSize(f.size),
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

// ---- primary CTA ---------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.brandBlue,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- phase cards ---------------------------------------------------------

class _WorkingCard extends StatelessWidget {
  final String status;
  const _WorkingCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          status.isEmpty ? 'Working…' : status,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this page open until the video is saved.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  final bool ready;
  final VoidCallback onAnother;
  const _DoneCard({required this.ready, required this.onAnother});

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      children: [
        Icon(
          ready ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          size: 52,
          color: ready ? AppColors.iconGreen : AppColors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          ready ? 'Your video is saved' : 'Saved — still processing',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ready
              ? 'The video has been transcoded and added to your library.'
              : "It's saved to your library and will be playable as soon as "
                    'the video service finishes transcoding.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Upload another',
          icon: Icons.add_rounded,
          enabled: true,
          onTap: onAnother,
        ),
      ],
    );
  }
}

class _FailedCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FailedCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      children: [
        const Icon(Icons.error_outline_rounded, size: 52, color: _danger),
        const SizedBox(height: 16),
        Text(
          "Upload didn't finish",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Start over',
          icon: Icons.refresh_rounded,
          enabled: true,
          onTap: onRetry,
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      children: [
        const Icon(Icons.lock_outline_rounded, size: 52, color: AppColors.body),
        const SizedBox(height: 16),
        Text(
          'Sign in to upload',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading a video needs a signed-in account.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Sign in',
          icon: Icons.login_rounded,
          enabled: true,
          onTap: () => Navigator.of(context).pushNamed('/login'),
        ),
      ],
    );
  }
}

// Shared centered card used by the working/done/failed/sign-in states.
class _CenteredCard extends StatelessWidget {
  final List<Widget> children;
  const _CenteredCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
