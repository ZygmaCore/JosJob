import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_api.dart' show AuthException;
import '../services/documents_api.dart';
import '../services/open_link.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'document_video_page.dart';

part 'widgets/document_card.dart';
part 'widgets/share_sheet.dart';

// =========================================================================
// ATVETI STELLAR — Documents (with Google-Docs-style access sharing)
//
// Route '/documents'. Lists the documents the signed-in user can access,
// split into "Owned by me" (documents they can manage) and "Shared with me".
// The uploader/owner (and org admins) can open a document's Share sheet to
// decide who else may access it — by email, with a configurable expiry and an
// enable/disable ("allow") switch per person. Backed by the JSON API in
// services/documents_api.dart (StellarWeb.Api.DocumentController).
// =========================================================================

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final DocumentsApi _api = DocumentsApi();

  bool _loading = true;
  String? _error;
  List<DocItem> _docs = const [];

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
    if (!Session.instance.isSignedIn) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your documents.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await Session.instance.runAuthed(_api.listDocuments);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your session has expired. Please sign in again.';
      });
    } on DocApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openShareSheet(DocItem doc) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ShareSheet(api: _api, docId: doc.id, docTitle: doc.title),
    );
    // Sharing doesn't change what the owner sees, but refresh keeps things in
    // sync if anything else moved.
    if (mounted) _load();
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
          'Documents',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.brandBlue),
        ),
      );
    }
    if (_error != null) {
      return _MessageState(icon: Icons.error_outline_rounded, message: _error!);
    }
    if (_docs.isEmpty) {
      return const _MessageState(
        icon: Icons.folder_open_rounded,
        message:
            'No documents yet. Uploaded videos and shared documents will '
            'appear here.',
      );
    }

    // Partition by relationship, not just canManage: org-admins/superusers can
    // manage docs they don't own, so those belong in their own section rather
    // than under "Owned by me".
    final owned = _docs.where((d) => d.relationship == 'owner').toList();
    final orgManaged = _docs
        .where((d) => d.canManage && d.relationship != 'owner')
        .toList();
    final shared = _docs.where((d) => !d.canManage).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (owned.isNotEmpty) ...[
                  const _SectionHeader('Owned by me'),
                  ...owned.map(_manageableCard),
                ],
                if (orgManaged.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeader('From your organization'),
                  ...orgManaged.map(_manageableCard),
                ],
                if (shared.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeader('Shared with me'),
                  ...shared.map(
                    (d) => _DocumentCard(doc: d, onOpen: () => _open(d)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // A document the caller can manage → shows the Share action.
  Widget _manageableCard(DocItem d) => _DocumentCard(
    doc: d,
    onOpen: () => _open(d),
    onShare: () => _openShareSheet(d),
  );

  // Video documents play in-app (HLS via hls.js) — a raw .m3u8 opened in a
  // browser tab won't play. Everything else opens in a new tab.
  void _open(DocItem doc) {
    if (doc.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentVideoPage(title: doc.title, url: doc.url),
        ),
      );
    } else {
      openLink(doc.url);
    }
  }
}

// ---- library-private shared helpers --------------------------------------

// "Aug 1, 2026" — a lightweight date format (no intl dependency).
const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime dt) {
  final d = dt.toLocal();
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.body,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _MessageState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    // Wrapped so RefreshIndicator can still pull even when empty/error.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppColors.body),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.body,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
