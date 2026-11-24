part of 'landing_page_ascent.dart';

class _AskAiDrawer extends StatefulWidget {
  const _AskAiDrawer({required this.onClose});
  final VoidCallback onClose;
  @override
  State<_AskAiDrawer> createState() => _AskAiDrawerState();
}

class _AskAiDrawerState extends State<_AskAiDrawer> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Map<String, String>>[];
  bool _busy = false;
  bool _closing = false;
  String? _error;

  void _close() {
    if (_closing) return;
    setState(() => _closing = true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _busy = true;
      _error = null;
      _history.add({'role': 'user', 'content': text});
    });
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/assistant/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': _history.length > 10
                  ? _history.sublist(_history.length - 10)
                  : _history,
            }),
          )
          .timeout(const Duration(seconds: 35));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          data is! Map ||
          data['answer'] is! String) {
        throw Exception('assistant_unavailable');
      }
      if (!mounted) return;
      setState(
        () => _history.add({
          'role': 'assistant',
          'content': data['answer'] as String,
        }),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'I couldn’t reach the assistant. Please try again in a moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              color: Colors.black.withValues(alpha: _closing ? 0 : .25),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(
              begin: _closing ? Offset.zero : const Offset(1, 0),
              end: _closing ? const Offset(1, 0) : Offset.zero,
            ),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            onEnd: () {
              if (_closing) widget.onClose();
            },
            builder: (context, offset, child) =>
                FractionalTranslation(translation: offset, child: child),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Material(
                color: Colors.white,
                elevation: 18,
                child: SizedBox(
                  width: width < 620
                      ? width
                      : width < 900
                      ? width * .78
                      : 430,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xffe9f1ff),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xff2563eb),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Assistant',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Ask anything about JosJob',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xff64748b),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('ask-ai-close'),
                                tooltip: 'Close assistant',
                                onPressed: _close,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _history.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(28),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.forum_outlined,
                                          size: 36,
                                          color: Color(0xff2563eb),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'How can I help?',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Ask about jobs, learning, coaching, or how to use JosJob.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xff64748b),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.all(18),
                                  itemCount: _history.length + (_busy ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _history.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final message = _history[index];
                                    final user = message['role'] == 'user';
                                    return Align(
                                      alignment: user
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(13),
                                        constraints: const BoxConstraints(
                                          maxWidth: 330,
                                        ),
                                        decoration: BoxDecoration(
                                          color: user
                                              ? const Color(0xffeaf1ff)
                                              : const Color(0xfff4f6fa),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: MarkdownBody(
                                          data: message['content']!,
                                          selectable: true,
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(height: 1.5),
                                            h1: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            h2: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            h3: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            code: const TextStyle(
                                              fontFamily: 'monospace',
                                              backgroundColor: Color(
                                                0xffe9edf3,
                                              ),
                                            ),
                                            blockquoteDecoration:
                                                const BoxDecoration(
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: Color(0xff2563eb),
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 5,
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Ask me anything...',
                                    filled: true,
                                    fillColor: const Color(0xfff5f7fa),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                key: const ValueKey('ask-ai-send'),
                                tooltip: 'Send message',
                                onPressed: _busy || _input.text.trim().isEmpty
                                    ? null
                                    : _send,
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
