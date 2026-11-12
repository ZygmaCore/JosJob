import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/documents_api.dart';
import '../services/session.dart';
import '../services/vod_document_api.dart';
import '../theme/app_theme.dart';

// =========================================================================
// JosJob — Teacher: upload a document (video / PDF / DOC)
//
// A single "upload a file" flow (route '/teacher/documents/upload') that
// handles BOTH media kinds, each with a real upload path, and persists the
// result as a standalone JosjobDoc.Document (course_id null — not tied to any
// course):
//
//   • VIDEO (mp4/mov/webm/…): direct-upload to Cloudflare Stream, then
//     POST /api/vod/documents (mirrors the existing VOD flow).
//   • PDF / DOC (pdf/doc/docx): presigned PUT straight to object storage
//     (S3/R2) via POST /api/documents/upload-url, then POST /api/documents.
//
// Three visible steps: choose → upload → done. Requires a signed-in session.
// A standalone library (needs its own file_picker import), mirroring
// vod_document_upload_page.dart's structure.
// =========================================================================

const Color _danger = Color(0xFFD64B4B);

const List<String> _videoExts = ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'];
const List<String> _docExts = ['pdf', 'doc', 'docx'];

bool _isVideoExt(String? ext) => _videoExts.contains((ext ?? '').toLowerCase());

// Map a picked file's extension to a mime_type stored on the Document.
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
      return 'video/mp4';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return 'application/octet-stream';
  }
}

class UploadDocumentPage extends StatefulWidget {
  const UploadDocumentPage({super.key});

  @override
  State<UploadDocumentPage> createState() => _UploadDocumentPageState();
}

enum _Phase { form, working, done, failed }

class _UploadDocumentPageState extends State<UploadDocumentPage> {
  final DocumentsApi _docs = DocumentsApi();
  final VodDocumentApi _vod = VodDocumentApi();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  PlatformFile? _file;

  _Phase _phase = _Phase.form;
  String _status = '';
  String? _error;
  bool _processing = false; // video still transcoding on the done screen

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _docs.close();
    _vod.close();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [..._videoExts, ..._docExts],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _file = result.files.single;
      // Prefill the title with the file's base name on first pick.
      if (_titleCtrl.text.trim().isEmpty) {
        final name = _file!.name;
        final dot = name.lastIndexOf('.');
        _titleCtrl.text = dot > 0 ? name.substring(0, dot) : name;
      }
    });
  }

  bool get _canUpload =>
      _titleCtrl.text.trim().isNotEmpty && _file?.bytes != null;

  Future<void> _startUpload() async {
    final token = Session.instance.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _phase = _Phase.failed;
        _error = 'Please sign in to upload a document.';
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
      if (_isVideoExt(file.extension)) {
        await _uploadVideo(token, file, bytes);
      } else {
        await _uploadFile(token, file, bytes);
      }
    } on VodDocException catch (e) {
      _fail(e.message);
    } on DocApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  // VIDEO → Cloudflare Stream, then persist as a Document; poll transcode.
  Future<void> _uploadVideo(
    String token,
    PlatformFile file,
    List<int> bytes,
  ) async {
    setState(() => _status = 'Preparing upload…');
    final ticket = await _vod.requestUploadUrl(token);

    if (!mounted) return;
    setState(() => _status = 'Uploading “${file.name}”…');
    await _vod.uploadToCloudflare(
      ticket.uploadUrl,
      bytes,
      filename: file.name,
      contentType: _mimeForExtension(file.extension),
    );

    if (!mounted) return;
    setState(() => _status = 'Saving video…');
    await _vod.createDocument(
      token,
      uid: ticket.uid,
      title: _titleCtrl.text.trim(),
      mimeType: _mimeForExtension(file.extension),
      description: _descCtrl.text.trim(),
    );

    // Best-effort poll — the Document already exists regardless of the outcome.
    bool ready = false;
    try {
      ready = await _pollUntilReady(token, ticket.uid);
    } on VodDocException {
      ready = false;
    }
    if (!mounted) return;
    setState(() {
      _processing = !ready;
      _phase = _Phase.done;
    });
  }

  // PDF/DOC → object storage (presigned PUT), then persist as a Document.
  Future<void> _uploadFile(
    String token,
    PlatformFile file,
    List<int> bytes,
  ) async {
    setState(() => _status = 'Preparing upload…');
    final ticket = await _docs.requestUploadUrl(token, filename: file.name);

    if (!mounted) return;
    setState(() => _status = 'Uploading “${file.name}”…');
    await _docs.uploadBytes(
      ticket.uploadUrl,
      bytes,
      contentType: _mimeForExtension(file.extension),
    );

    if (!mounted) return;
    setState(() => _status = 'Saving document…');
    await _docs.createDocument(
      token,
      title: _titleCtrl.text.trim(),
      url: ticket.publicUrl,
      mimeType: _mimeForExtension(file.extension),
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _processing = false;
      _phase = _Phase.done;
    });
  }

  Future<bool> _pollUntilReady(String token, String uid) async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      VodDocStatus s;
      try {
        s = await _vod.fetchStatus(token, uid);
      } on VodDocException catch (e) {
        if (e.statusCode == 401) rethrow;
        continue;
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

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  void _reset() {
    setState(() {
      _phase = _Phase.form;
      _status = '';
      _error = null;
      _processing = false;
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
          'Upload a document',
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
        return _DoneCard(
          processing: _processing,
          onAnother: _reset,
          onFinish: () => Navigator.of(context).maybePop(true),
        );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepStrip(active: _file == null ? 0 : 1),
        const SizedBox(height: 16),
        Card(
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
                const _FieldLabel('Title'),
                TextField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(hint: 'e.g. Course syllabus'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel('Description (optional)'),
                TextField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _fieldDecoration(
                    hint: 'What is this document about?',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel('File'),
                _FilePickTile(file: _file, onPick: _pickFile),
                const SizedBox(height: 24),
                _PrimaryButton(
                  label: 'Upload document',
                  icon: Icons.cloud_upload_outlined,
                  enabled: _canUpload,
                  onTap: _startUpload,
                ),
                const SizedBox(height: 10),
                Text(
                  'Supported: video (mp4, mov, webm…), PDF and Word documents. '
                  'The file is stored and added to your document library — it is '
                  'not attached to any course.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.body,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- step strip ("choose → upload → done") ------------------------------

class _StepStrip extends StatelessWidget {
  final int active; // 0 = choose a file, 1 = file chosen (ready to upload)
  const _StepStrip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(index: 1, label: 'Choose', done: active >= 1),
        const _StepLine(),
        _StepDot(index: 2, label: 'Upload', done: false),
        const _StepLine(),
        _StepDot(index: 3, label: 'Done', done: false),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  const _StepDot({
    required this.index,
    required this.label,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final active = done || index == 1;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlue : AppColors.tintBlue,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '$index',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.brandBlue,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.body),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      color: AppColors.border,
    ),
  );
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

class _FilePickTile extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onPick;
  const _FilePickTile({required this.file, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final f = file;
    final video = _isVideoExt(f?.extension);
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
                  ? Icons.upload_file_outlined
                  : (video
                        ? Icons.videocam_outlined
                        : Icons.description_outlined),
              color: f == null ? AppColors.body : AppColors.iconBlue,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                f == null ? 'Choose a file (video, PDF or DOC)' : f.name,
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
          'Keep this page open until the document is saved.',
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
  final bool processing;
  final VoidCallback onAnother;
  final VoidCallback onFinish;
  const _DoneCard({
    required this.processing,
    required this.onAnother,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      children: [
        Icon(
          processing ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
          size: 52,
          color: processing ? AppColors.orange : AppColors.iconGreen,
        ),
        const SizedBox(height: 16),
        Text(
          processing ? 'Saved — still processing' : 'Document saved',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          processing
              ? 'It has been saved to your library and will be playable once '
                    'the video service finishes transcoding.'
              : 'It has been added to your document library.',
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
        const SizedBox(height: 10),
        TextButton(
          onPressed: onFinish,
          child: Text(
            'Back to documents',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
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
