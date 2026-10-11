import 'dart:math';

import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/realtime.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';

import 'fake_realtime.dart';
import 'fake_sync_server.dart';

const ws = 'w1';

/// One device: its own database, repository, engine, real-time client and
/// network switch, all talking to a shared [FakeSyncServer].
class Device {
  Device(FakeSyncServer server, String userId)
    : db = AppDatabase(NativeDatabase.memory()),
      api = FakeSyncApi(server, userId),
      transport = FakeRealtimeTransport(server) {
    realtime = RealtimeClient(
      transport: transport,
      token: ({refresh = false}) async => 'token-$userId',
    );
    repo = DriftBoardsRepository(db, watchRoom: realtime.watch);
    store = SyncStore(db);
    engine = SyncEngine(
      store: store,
      api: api,
      debounce: const Duration(milliseconds: 10),
      random: Random(1),
    );
  }

  final AppDatabase db;
  final FakeSyncApi api;
  final FakeRealtimeTransport transport;
  late final RealtimeClient realtime;
  late final DriftBoardsRepository repo;
  late final SyncStore store;
  late final SyncEngine engine;

  Future<void> join() => db
      .into(db.cachedWorkspaces)
      .insert(
        CachedWorkspacesCompanion.insert(
          id: ws,
          name: 'Team',
          role: 'member',
          memberCount: 2,
        ),
      );

  /// Starts the engine (first cycle) and waits until it settles. Real-time
  /// events trigger cycles only after [realtime] is started.
  Future<SyncStatus> sync() async {
    if (!engine.isStarted) engine.start(triggers: [realtime.changes]);
    await engine.syncNow();
    return engine.status;
  }

  Future<BoardContent?> board(String id) => repo.watchBoard(id).first;

  Future<void> close() async {
    await realtime.dispose();
    await engine.dispose();
    await db.close();
  }
}
