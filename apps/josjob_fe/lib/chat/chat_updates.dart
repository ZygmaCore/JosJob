import 'dart:async';
import 'package:phoenix_socket/phoenix_socket.dart';
import '../services/api_config.dart';
import '../services/session.dart';

/// Live messages are a refresh signal; REST remains the source of truth.
class ChatUpdates {
  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;
  Future<void> connect(String kind, String id, void Function() refresh) async {
    try {
      final socket = PhoenixSocket(
        '${ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/socket/websocket',
        socketOptions: PhoenixSocketOptions(
          dynamicParams: () async => {
            'token': Session.instance.accessToken ?? '',
          },
        ),
      );
      _socket = socket;
      await socket.connect().timeout(const Duration(seconds: 10));
      if (_disposed) return;
      final channel = socket.addChannel(topic: 'chat:$kind:$id');
      _channel = channel;
      _subscription = channel.messages
          .where((m) => m.event.value == 'message_created')
          .listen((_) => refresh());
      await channel.join().future.timeout(const Duration(seconds: 10));
      if (!_disposed) refresh();
    } catch (_) {
      // The panel also refreshes on a timer, so a disconnected socket loses no history.
    }
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _channel?.leave();
    _socket?.dispose();
  }
}
