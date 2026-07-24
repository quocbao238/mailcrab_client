import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';

enum WsStatus { connecting, connected, disconnected }

/// Listens on MailCrab's `/ws` endpoint for new-message events and
/// reconnects automatically with exponential backoff.
class WsListener {
  final Uri wsUri;
  final void Function(MailMessageMetadata metadata) onMessage;
  final void Function(WsStatus status) onStatus;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 2);
  bool _disposed = false;

  WsListener({
    required this.wsUri,
    required this.onMessage,
    required this.onStatus,
  });

  void connect() {
    if (_disposed) return;
    onStatus(WsStatus.connecting);
    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      channel.ready.then((_) {
        if (_disposed) return;
        debugPrint('MailCrab ws: connected to $wsUri');
        _backoff = const Duration(seconds: 2);
        onStatus(WsStatus.connected);
        _subscription = channel.stream.listen(
          _handleFrame,
          onError: (Object e) {
            debugPrint('MailCrab ws: stream error: $e');
            _scheduleReconnect();
          },
          onDone: _scheduleReconnect,
          cancelOnError: true,
        );
      }).catchError((Object e) {
        // e.g. an HTTP 400 from a proxy that strips upgrade headers —
        // the stream may never emit in this case, so reconnect from here.
        debugPrint('MailCrab ws: handshake failed: $e');
        _scheduleReconnect();
      });
    } catch (e) {
      debugPrint('MailCrab ws: connect threw: $e');
      _scheduleReconnect();
    }
  }

  void _handleFrame(dynamic frame) {
    if (frame is! String) return;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is Map<String, dynamic> && decoded['id'] is String) {
        onMessage(MailMessageMetadata.fromJson(decoded));
      }
    } catch (e) {
      debugPrint('MailCrab ws: could not parse frame: $e');
    }
  }

  /// Sends a MailCrab action, e.g. `{"Open": "<id>"}` or `"RemoveAll"`.
  /// No-op when the socket is down; callers should not rely on delivery.
  void send(Object action) {
    try {
      _channel?.sink.add(jsonEncode(action));
    } catch (_) {}
  }

  void markOpened(String id) => send({'Open': id});

  void _scheduleReconnect() {
    if (_disposed) return;
    onStatus(WsStatus.disconnected);
    _teardownChannel();
    _reconnectTimer?.cancel();
    debugPrint('MailCrab ws: retrying in ${_backoff.inSeconds}s');
    _reconnectTimer = Timer(_backoff, connect);
    final next = _backoff * 2;
    _backoff = next > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : next;
  }

  void _teardownChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardownChannel();
  }
}
