import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_api.dart';
import '../services/session.dart';
import '../services/workflow_client.dart';
import '../theme/app_theme.dart';
import '../shared/app_formats.dart';
import 'chat_updates.dart';

/// Every hiring and coaching conversation uses this same surface and composer.
class ChatPage extends StatelessWidget {
  final String kind, contextId, title;
  final ChatApi? api;
  final WorkflowAuthorize? authorize;
  final bool realtime;
  const ChatPage({
    super.key,
    required this.kind,
    required this.contextId,
    required this.title,
    this.api,
    this.authorize,
    this.realtime = true,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ChatPanel(
            kind: kind,
            contextId: contextId,
            api: api,
            authorize: authorize,
            realtime: realtime,
          ),
        ),
      ),
    ),
  );
}

class ChatPanel extends StatefulWidget {
  final String kind, contextId;
  final ChatApi? api;
  final WorkflowAuthorize? authorize;
  final bool realtime;
  const ChatPanel({
    super.key,
    required this.kind,
    required this.contextId,
    this.api,
    this.authorize,
    this.realtime = true,
  });
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final ChatApi _api = widget.api ?? ChatApi();
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _updates = ChatUpdates();
  final _messages = <String, ChatMessage>{};
  ChatHistory? _thread;
  Timer? _timer;
  bool _loading = true, _fetching = false, _older = false, _sending = false;
  String? _error, _nextBefore, _pendingId, _pendingBody;
  Future<T> _auth<T>(Future<T> Function(String) call) =>
      (widget.authorize ?? Session.instance.runAuthed)(call);

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.realtime) {
      unawaited(_updates.connect(widget.kind, widget.contextId, () => _load()));
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _updates.dispose();
    _draft.dispose();
    _scroll.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });
  Future<void> _load({bool older = false}) async {
    if (!mounted || _fetching || (older && _nextBefore == null)) return;
    _fetching = true;
    if (older) setState(() => _older = true);
    final follow =
        _loading || (!_scroll.hasClients || _scroll.position.extentAfter < 90);
    final oldExtent = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    try {
      final result = await _auth(
        (t) => _api.history(
          t,
          widget.kind,
          widget.contextId,
          before: older ? _nextBefore : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        for (final m in result.messages) {
          _messages[m.id] = m;
        }
        _thread = result;
        if (older || _loading) _nextBefore = result.nextBefore;
        _error = null;
      });
      if (older) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(
              oldOffset + _scroll.position.maxScrollExtent - oldExtent,
            );
          }
        });
      } else if (follow) {
        _bottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (e is WorkflowException && e.statusCode == 404) {
            _messages.clear();
            _thread = null;
          }
        });
      }
    } finally {
      _fetching = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _older = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (_sending || body.isEmpty || _thread?.canSend != true) return;
    if (body.length > 4000) {
      setState(() => _error = 'Keep messages within 4,000 characters.');
      return;
    }
    if (_pendingBody != body) {
      _pendingBody = body;
      // A shifted bound (1 << 32) becomes zero when compiled for the web.
      _pendingId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await _auth(
        (t) => _api.send(t, widget.kind, widget.contextId, body, _pendingId!),
      );
      if (!mounted) return;
      setState(() {
        _messages[message.id] = message;
        _pendingId = null;
        _pendingBody = null;
      });
      _draft.clear();
      _bottom();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  TextStyle _text(
    double size, {
    Color color = AppColors.ink,
    bool bold = false,
  }) => GoogleFonts.poppins(
    fontSize: size,
    color: color,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
  );
  String _time(DateTime value) {
    return AppFormats.dateTime(value, showZone: true);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages.values.toList()
      ..sort((a, b) => BigInt.parse(a.id).compareTo(BigInt.parse(b.id)));
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        key: const ValueKey('shared-chat'),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.tintBlue,
                  child: Icon(Icons.forum_outlined, color: AppColors.brandBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _thread?.title ?? 'Conversation',
                        style: _text(15, bold: true),
                      ),
                      Text(
                        _thread?.subtitle ?? 'Private messages',
                        style: _text(12, color: AppColors.body),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('refresh-chat'),
                  tooltip: 'Refresh messages',
                  onPressed: _fetching ? null : () => _load(),
                  icon: const Icon(Icons.refresh, color: AppColors.brandBlue),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.paper2,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      key: const ValueKey('chat-error'),
                      style: _text(12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 44,
                            color: AppColors.iconBlue,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _thread == null
                                ? 'Conversation unavailable'
                                : 'Start the conversation',
                            key: const ValueKey('chat-empty'),
                            style: _text(17, bold: true),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Messages are saved here for both participants.',
                            style: _text(12, color: AppColors.body),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('chat-messages'),
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _nextBefore == null
                            ? const SizedBox.shrink()
                            : Center(
                                child: TextButton(
                                  key: const ValueKey('chat-load-older'),
                                  onPressed: _older
                                      ? null
                                      : () => _load(older: true),
                                  child: Text(
                                    _older
                                        ? 'Loading…'
                                        : 'Load earlier messages',
                                  ),
                                ),
                              );
                      }
                      final m = messages[i - 1];
                      final own = m.senderId == _thread?.selfId;
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          key: ValueKey('message-${m.id}'),
                          constraints: const BoxConstraints(maxWidth: 580),
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: own ? AppColors.brandBlue : AppColors.paper2,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                own ? 'You' : m.senderName,
                                style: _text(
                                  11,
                                  color: own ? Colors.white : AppColors.navy,
                                  bold: true,
                                ),
                              ),
                              const SizedBox(height: 5),
                              SelectableText(
                                m.body,
                                style: _text(
                                  14,
                                  color: own ? Colors.white : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _time(m.createdAt),
                                style: _text(
                                  10,
                                  color: own ? Colors.white : AppColors.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _thread != null && !_thread!.canSend
                ? Text(
                    'This conversation is read-only. Your message history is still available.',
                    key: const ValueKey('chat-read-only'),
                    style: _text(12, color: AppColors.body),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('chat-draft'),
                          controller: _draft,
                          enabled: !_sending && _thread != null,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          style: _text(14),
                          decoration: InputDecoration(
                            hintText: 'Write a message…',
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.brandBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        key: const ValueKey('chat-send'),
                        onPressed: _sending || _thread == null ? null : _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                semanticLabel: 'Send message',
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
