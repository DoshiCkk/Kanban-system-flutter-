import 'dart:async';

import 'package:flowboard/core/sync/realtime.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// [RealtimeTransport] over Socket.IO (WebSocket only; the API's gateway
/// shares the REST port).
class SocketIoTransport implements RealtimeTransport {
  SocketIoTransport(this._url);

  /// Server events that mean "pull now" (docs/realtime.md).
  static const serverEvents = ['board:changed', 'workspace:removed'];
  static const _ackTimeout = Duration(seconds: 10);

  final String _url;
  final _events = StreamController<TransportEvent>.broadcast();
  io.Socket? _socket;

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  void connect(Future<String?> Function() token) {
    _socket?.dispose();
    final socket =
        io.io(
            _url,
            io.OptionBuilder()
                .setTransports(['websocket'])
                .disableAutoConnect()
                // A new manager per connect: never reuse a signed-out session.
                .enableForceNew()
                .setReconnectionDelay(1000)
                .setReconnectionDelayMax(30000)
                .setAuthFn((send) {
                  unawaited(
                    token().then(
                      (value) => send({'token': ?value}),
                      onError: (Object _) => send({}),
                    ),
                  );
                })
                .build(),
          )
          ..onConnect((_) => _events.add(const TransportConnected()))
          ..onDisconnect(
            (reason) => _events.add(
              TransportDisconnected(byServer: reason == 'io server disconnect'),
            ),
          )
          ..onConnectError((error) {
            // A refused handshake arrives as {message, data}; network errors
            // are retried by the socket's own reconnection.
            if (error is Map && error['message'] == 'UNAUTHORIZED') {
              _events.add(const TransportRejected());
            }
          });
    for (final event in serverEvents) {
      socket.on(event, (_) => _events.add(TransportMessage(event)));
    }
    _socket = socket..connect();
  }

  @override
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  @override
  Future<JoinResult> join(String boardId) async {
    final ack = await _request('board:join', boardId);
    if (ack == null) return JoinResult.failed;
    return ack['ok'] == true ? JoinResult.joined : JoinResult.notFound;
  }

  @override
  Future<void> leave(String boardId) => _request('board:leave', boardId);

  Future<Map<dynamic, dynamic>?> _request(String event, String boardId) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return null;
    try {
      final ack = await socket
          .timeout(_ackTimeout.inMilliseconds)
          .emitWithAckAsync(event, {'boardId': boardId});
      return ack is Map ? ack : null;
    } on Object catch (e) {
      debugPrint('realtime: $event failed: $e');
      return null;
    }
  }
}
