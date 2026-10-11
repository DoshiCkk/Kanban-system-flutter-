import 'dart:async';

import 'package:flowboard/core/sync/realtime.dart';

import 'fake_sync_server.dart';

/// [RealtimeTransport] in memory. With a [server], joins check that the
/// board exists there and the server's board changes reach joined rooms
/// (like the API's gateway); otherwise [known] lists joinable boards.
class FakeRealtimeTransport implements RealtimeTransport {
  FakeRealtimeTransport([this.server]);

  final FakeSyncServer? server;
  final _events = StreamController<TransportEvent>.broadcast();
  StreamSubscription<String>? _serverChanges;

  /// Whether the server accepts a handshake token.
  bool Function(String? token) accepts = (token) => token != null;

  final known = <String>{};
  final handshakes = <String?>[];
  final joins = <String>[];
  final leaves = <String>[];
  final rooms = <String>{};
  bool connected = false;

  /// When set, join acks wait for it (a join in flight).
  Completer<void>? holdJoins;

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  void connect(Future<String?> Function() token) {
    unawaited(_handshake(token));
  }

  Future<void> _handshake(Future<String?> Function() token) async {
    final value = await token();
    handshakes.add(value);
    if (!accepts(value)) {
      _events.add(const TransportRejected());
      return;
    }
    connected = true;
    await _serverChanges?.cancel();
    _serverChanges = server?.boardChanges.listen((boardId) {
      if (connected && rooms.contains(boardId)) {
        _events.add(const TransportMessage('board:changed'));
      }
    });
    _events.add(const TransportConnected());
  }

  @override
  void disconnect() {
    connected = false;
    rooms.clear();
    unawaited(_serverChanges?.cancel());
  }

  @override
  Future<JoinResult> join(String boardId) async {
    joins.add(boardId);
    await holdJoins?.future;
    if (!connected) return JoinResult.failed;
    final row = server?.rows['board']![boardId];
    final exists = server == null
        ? known.contains(boardId)
        : row != null && row['deletedAt'] == null;
    if (!exists) return JoinResult.notFound;
    rooms.add(boardId);
    return JoinResult.joined;
  }

  @override
  Future<void> leave(String boardId) async {
    leaves.add(boardId);
    rooms.remove(boardId);
  }

  /// The server pushes [event] to this client.
  void serverEvent([String event = 'board:changed']) =>
      _events.add(TransportMessage(event));

  /// A network drop, or a server-side close when [byServer] (token expiry).
  void drop({bool byServer = false}) {
    connected = false;
    rooms.clear();
    _events.add(TransportDisconnected(byServer: byServer));
  }

  /// The socket's own reconnect after a network drop.
  void reconnect() {
    connected = true;
    _events.add(const TransportConnected());
  }
}
