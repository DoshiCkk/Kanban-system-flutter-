import 'dart:math';

import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sync_server.dart';

const ws = 'w1';

/// One device: its own database, repository, engine and network switch.
class Device {
  Device(FakeSyncServer server, String userId)
    : db = AppDatabase(NativeDatabase.memory()),
      api = FakeSyncApi(server, userId) {
    repo = DriftBoardsRepository(db);
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

  /// Starts the engine (first cycle) and waits until it settles.
  Future<SyncStatus> sync() async {
    if (!engine.isStarted) {
      engine.start();
    }
    await engine.syncNow();
    return engine.status;
  }

  Future<BoardContent?> board(String id) => repo.watchBoard(id).first;

  Future<void> close() async {
    await engine.dispose();
    await db.close();
  }
}

void main() {
  late FakeSyncServer server;
  late Device alice;
  late Device bob;

  setUp(() async {
    server = FakeSyncServer(pageSize: 4);
    alice = Device(server, 'alice');
    bob = Device(server, 'bob');
    await alice.join();
    await bob.join();
  });

  tearDown(() async {
    await alice.close();
    await bob.close();
  });

  Future<BoardContent> seed() async {
    final board = await alice.repo.createBoard(
      workspaceId: ws,
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Doing', 'Done'],
    );
    final todo = (await alice.board(board.id))!.columns.first.column.id;
    await alice.repo.createCard(todo, 'Intro');
    await alice.repo.createCard(todo, 'Survey');
    return (await alice.board(board.id))!;
  }

  test('pushes the outbox and pulls into another device', () async {
    final content = await seed();
    final status = await alice.sync();
    expect(status, const SyncStatus());
    expect(await alice.store.pendingCount(), 0);

    await bob.sync();
    final onBob = (await bob.board(content.board.id))!;
    expect(
      onBob.columns.map((c) => c.column.title),
      ['To do', 'Doing', 'Done'],
    );
    // 1 board + 3 columns + 2 cards with pages of 4 → paging worked.
    expect(onBob.columns.first.cards.map((c) => c.title), ['Intro', 'Survey']);
  });

  test('offline keeps changes queued and retries with backoff', () async {
    await seed();
    alice.api.offline = true;
    final status = await alice.sync();
    expect(status.phase, SyncPhase.offline);
    expect(status.pending, 6);
    // Let the debounced trigger fail too, so only the backoff timer is left.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(alice.engine.status.phase, SyncPhase.offline);

    alice.api.offline = false;
    final watch = Stopwatch()..start();
    // The retry is scheduled 0.5–1 s after the last failure.
    final synced = await alice.engine.statusChanges
        .firstWhere((s) => s.synced)
        .timeout(const Duration(seconds: 3));
    expect(watch.elapsedMilliseconds, greaterThan(300));
    expect(synced.pending, 0);
    expect(server.rows['card'], hasLength(2));
  });

  test('a local change triggers a sync on its own', () async {
    final content = await seed();
    await alice.sync();
    final pushes = server.pushCalls;

    await alice.repo.renameBoard(content.board.id, 'Thesis');
    await alice.engine.statusChanges
        .firstWhere((s) => s.synced)
        .timeout(const Duration(seconds: 2));
    expect(server.pushCalls, pushes + 1);
    expect(server.rows['board']!.values.single['title'], 'Thesis');
  });

  test('a create rejected by the server disappears locally', () async {
    final content = await seed();
    await alice.sync();
    await bob.sync();
    final done = content.columns[2].column.id;

    await alice.repo.deleteColumn(done);
    await alice.sync();
    bob.api.offline = true;
    await bob.repo.createCard(done, 'Orphan');
    bob.api.offline = false;
    await bob.sync();

    final onBob = (await bob.board(content.board.id))!;
    expect(onBob.columns.map((c) => c.column.title), ['To do', 'Doing']);
    expect(await bob.store.pendingCount(), 0);
    expect(server.rows['card']!.values.map((c) => c['title']), [
      'Intro',
      'Survey',
    ]);
  });

  test('a rejected update is undone by a full pull', () async {
    final content = await seed();
    await alice.sync();
    await bob.sync();
    final intro = content.columns[0].cards.first.id;
    final done = content.columns[2].column.id;

    // Bob moves a card into "Done" while Alice deletes "Done".
    bob.api.offline = true;
    await bob.repo.moveCard(intro, toColumnId: done, toIndex: 0);
    await alice.repo.deleteColumn(done);
    await alice.sync();
    bob.api.offline = false;
    await bob.sync();

    final onBob = (await bob.board(content.board.id))!;
    expect(onBob.columns.first.cards.map((c) => c.id), contains(intro));
  });

  test('losing access forgets the workspace', () async {
    final content = await seed();
    await alice.sync();
    await bob.sync();
    expect(await bob.board(content.board.id), isNotNull);

    bob.api.removedFrom.add(ws);
    await bob.sync();
    expect(await bob.board(content.board.id), isNull);
    expect(await bob.store.workspaceIds(), isEmpty);
  });

  test(
    'two devices editing offline converge (field LWW, delete wins)',
    () async {
      final content = await seed();
      await alice.sync();
      await bob.sync();
      final intro = content.columns[0].cards[0].id;
      final survey = content.columns[0].cards[1].id;
      final doing = content.columns[1].column.id;

      alice.api.offline = true;
      bob.api.offline = true;
      // Different fields of one card: both survive.
      await alice.repo.updateCard(
        intro,
        const CardPatch(title: 'Introduction'),
      );
      await bob.repo.moveCard(intro, toColumnId: doing, toIndex: 0);
      await bob.repo.updateCard(
        intro,
        const CardPatch(description: 'Two pages'),
      );
      // Same field: the later push wins (Bob syncs last).
      await alice.repo.updateCard(survey, const CardPatch(title: 'Alice'));
      await bob.repo.updateCard(survey, const CardPatch(title: 'Bob'));
      // Delete wins over a concurrent edit.
      final temp = await alice.repo.createCard(doing, 'Temp');
      alice.api.offline = false;
      await alice.sync();
      bob.api.offline = false;
      await bob.sync();
      alice.api.offline = true;
      await alice.repo.deleteCard(temp.id);
      await bob.repo.updateCard(temp.id, const CardPatch(title: 'Edited'));
      alice.api.offline = false;

      await alice.sync();
      await bob.sync();
      await alice.sync();

      final a = (await alice.board(content.board.id))!;
      final b = (await bob.board(content.board.id))!;
      expect(a.columns, b.columns);
      expect(a.columns[0].cards.map((c) => c.title), ['Bob']);
      expect(a.columns[1].cards.map((c) => c.title), ['Introduction']);
      final introOnAlice = (await alice.repo.watchCard(intro).first)!;
      expect(introOnAlice.description, 'Two pages');
      expect(await alice.store.pendingCount(), 0);
      expect(await bob.store.pendingCount(), 0);
    },
  );
}
