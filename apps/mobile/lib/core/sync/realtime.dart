import 'dart:async';
import 'dart:math';

import 'package:flowboard/core/network/access_token.dart';

/// Keeps live updates of a board on while it is on screen: joins the
/// board's room until the returned callback runs.
typedef WatchBoardRoom = void Function() Function(String boardId);

/// For tests and code paths without real-time.
void Function() noBoardRoom(String boardId) => () {};

enum JoinResult {
  joined,

  /// The server does not know the board (yet) or the user is not a member.
  notFound,

  /// No answer (disconnected, timeout); the next connect retries.
  failed,
}

sealed class TransportEvent {
  const TransportEvent();
}

class TransportConnected extends TransportEvent {
  const TransportConnected();
}

class TransportDisconnected extends TransportEvent {
  /// [byServer]: the server closed the socket (token expired) and the
  /// transport will not reconnect on its own.
  const TransportDisconnected({required this.byServer});

  final bool byServer;
}

/// The handshake was refused (invalid or expired token).
class TransportRejected extends TransportEvent {
  const TransportRejected();
}

/// A server event (docs/realtime.md), e.g. `board:changed`.
class TransportMessage extends TransportEvent {
  const TransportMessage(this.event);

  final String event;
}

/// The Socket.IO connection, behind an interface so tests can fake it.
abstract interface class RealtimeTransport {
  Stream<TransportEvent> get events;

  /// Connects, calling [token] for every handshake. After a network drop
  /// the transport reconnects by itself; after [TransportRejected] or a
  /// server-side disconnect the caller must call [connect] again.
  void connect(Future<String?> Function() token);

  void disconnect();

  Future<JoinResult> join(String boardId);

  Future<void> leave(String boardId);
}

/// Live updates (docs/realtime.md): joins `board:<id>` rooms of watched
/// boards and fires [changes] whenever the client should sync — a server
/// event, a (re)connect that may have missed events, or a board just opened.
class RealtimeClient {
  RealtimeClient({
    required this._transport,
    required this._token,
    this.retryBase = const Duration(seconds: 1),
    this.maxRetry = const Duration(minutes: 1),
  });

  final RealtimeTransport _transport;
  final AccessTokenGetter _token;
  final Duration retryBase;
  final Duration maxRetry;

  final _changes = StreamController<void>.broadcast();
  final _watchers = <String, int>{};
  final _joined = <String>{};

  /// Boards the server did not know yet (created offline); see
  /// [retryFailedJoins].
  final _notFound = <String>{};
  StreamSubscription<TransportEvent>? _events;
  Timer? _retryTimer;
  bool _started = false;
  bool _connected = false;
  bool _forceRefresh = false;
  int _rejections = 0;

  Stream<void> get changes => _changes.stream;

  bool get isConnected => _connected;

  void start() {
    if (_started) return;
    _started = true;
    _events = _transport.events.listen(_onEvent);
    _connect();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _retryTimer?.cancel();
    _transport.disconnect();
    _setDisconnected();
    _rejections = 0;
    await _events?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }

  void _connect() => _transport.connect(() {
    final refresh = _forceRefresh;
    _forceRefresh = false;
    return _token(refresh: refresh);
  });

  void _setDisconnected() {
    _connected = false;
    _joined.clear();
    _notFound.clear();
  }

  void _onEvent(TransportEvent event) {
    if (!_started) return;
    switch (event) {
      case TransportConnected():
        _connected = true;
        _rejections = 0;
        for (final boardId in _watchers.keys) {
          unawaited(_join(boardId));
        }
        // Events sent while we were offline are lost; catch up.
        _changes.add(null);
      case TransportDisconnected(:final byServer):
        _setDisconnected();
        // The access token expired; the handshake picks a fresh one.
        if (byServer) _connect();
      case TransportRejected():
        _setDisconnected();
        _scheduleReconnect();
      case TransportMessage():
        _changes.add(null);
    }
  }

  /// Retries right away with a refreshed token, then backs off (the
  /// server may keep refusing, e.g. while the refresh endpoint is down).
  void _scheduleReconnect() {
    final delay = _rejections == 0
        ? Duration.zero
        : Duration(
            milliseconds: min(
              retryBase.inMilliseconds * (1 << min(_rejections - 1, 16)),
              maxRetry.inMilliseconds,
            ),
          );
    _rejections++;
    _forceRefresh = true;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_started) _connect();
    });
  }

  /// A [WatchBoardRoom]. Overlapping watchers of one board share a join.
  void Function() watch(String boardId) {
    final count = _watchers[boardId] = (_watchers[boardId] ?? 0) + 1;
    if (count == 1 && _connected) unawaited(_join(boardId));
    var released = false;
    return () {
      if (released) return;
      released = true;
      final left = _watchers[boardId]! - 1;
      if (left > 0) {
        _watchers[boardId] = left;
        return;
      }
      _watchers.remove(boardId);
      _notFound.remove(boardId);
      if (_joined.remove(boardId) && _connected) {
        unawaited(_transport.leave(boardId));
      }
    };
  }

  Future<void> _join(String boardId) async {
    final result = await _transport.join(boardId);
    if (!_connected) return;
    final watched = _watchers.containsKey(boardId);
    switch (result) {
      case JoinResult.joined when watched:
        _joined.add(boardId);
        // The board was just opened (or the socket reconnected): fetch
        // what changed while it was not live.
        _changes.add(null);
      case JoinResult.joined:
        // Released while the join was in flight.
        await _transport.leave(boardId);
      case JoinResult.notFound when watched:
        _notFound.add(boardId);
      case JoinResult.notFound || JoinResult.failed:
        break;
    }
  }

  /// Re-joins boards the server did not know yet, e.g. a board created
  /// offline that the last sync has now pushed.
  void retryFailedJoins() {
    if (!_connected || _notFound.isEmpty) return;
    final boards = [..._notFound];
    _notFound.clear();
    for (final boardId in boards) {
      unawaited(_join(boardId));
    }
  }
}
