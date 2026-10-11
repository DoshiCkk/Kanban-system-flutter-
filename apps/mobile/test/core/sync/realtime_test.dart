import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/realtime.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device.dart';
import '../../helpers/fake_realtime.dart';
import '../../helpers/fake_sync_server.dart';

void main() {
  group('RealtimeClient', () {
    late FakeRealtimeTransport transport;
    late RealtimeClient client;
    late List<bool> tokenRequests;
    late String token;
    late int syncs;

    setUp(() {
      transport = FakeRealtimeTransport()..known.addAll(['b1', 'b2']);
      tokenRequests = [];
      token = 'valid';
      syncs = 0;
      client = RealtimeClient(
        transport: transport,
        token: ({refresh = false}) async {
          tokenRequests.add(refresh);
          if (refresh) token = 'refreshed';
          return token;
        },
        retryBase: const Duration(milliseconds: 100),
        maxRetry: const Duration(milliseconds: 400),
      );
      client.changes.listen((_) => syncs++);
    });

    tearDown(() => client.dispose());

    test('joins each watched board once and leaves after the last '
        'watcher', () async {
      final first = client.watch('b1');
      final second = client.watch('b1');
      client.start();
      await pumpEventQueue();
      expect(transport.joins, ['b1']);
      expect(transport.rooms, {'b1'});
      // Connected (catch up) + board joined (fresh on open).
      expect(syncs, 2);

      first();
      first();
      await pumpEventQueue();
      expect(transport.leaves, isEmpty);
      second();
      await pumpEventQueue();
      expect(transport.leaves, ['b1']);
    });

    test('a server event asks for a sync', () async {
      client.start();
      await pumpEventQueue();
      syncs = 0;
      transport.serverEvent();
      await pumpEventQueue();
      expect(syncs, 1);
    });

    test('re-joins rooms after the socket reconnects', () async {
      client
        ..watch('b1')
        ..watch('b2')
        ..start();
      await pumpEventQueue();
      transport.drop();
      await pumpEventQueue();
      expect(client.isConnected, isFalse);

      transport.reconnect();
      await pumpEventQueue();
      expect(transport.joins, ['b1', 'b2', 'b1', 'b2']);
      expect(transport.rooms, {'b1', 'b2'});
    });

    test('refreshes the token when the handshake is refused', () async {
      transport.accepts = (t) => t == 'refreshed';
      client.start();
      await pumpEventQueue();
      expect(tokenRequests, [false, true]);
      expect(transport.handshakes, ['valid', 'refreshed']);
      expect(client.isConnected, isTrue);

      // Token expired on the server: reconnect, without forcing a refresh.
      transport.drop(byServer: true);
      await pumpEventQueue();
      expect(tokenRequests, [false, true, false]);
      expect(client.isConnected, isTrue);
    });

    test('backs off while the server keeps refusing', () {
      fakeAsync((async) {
        transport.accepts = (_) => false;
        client.start();
        // Immediate retry with a refreshed token…
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero);
        expect(transport.handshakes, hasLength(2));
        // …then 100, 200, 400, 400 ms.
        async.elapse(const Duration(milliseconds: 100));
        expect(transport.handshakes, hasLength(3));
        async.elapse(const Duration(milliseconds: 200));
        expect(transport.handshakes, hasLength(4));
        async.elapse(const Duration(milliseconds: 399));
        expect(transport.handshakes, hasLength(4));
        async.elapse(const Duration(milliseconds: 1));
        expect(transport.handshakes, hasLength(5));
        async.elapse(const Duration(milliseconds: 400));
        expect(transport.handshakes, hasLength(6));

        unawaited(client.stop());
        async.elapse(const Duration(seconds: 5));
        expect(transport.handshakes, hasLength(6));
      });
    });

    test('retries a board the server did not know yet', () async {
      client
        ..watch('b3')
        ..start();
      await pumpEventQueue();
      expect(transport.rooms, isEmpty);

      // Still unknown: no harm in asking again.
      client.retryFailedJoins();
      await pumpEventQueue();
      expect(transport.joins, ['b3', 'b3']);

      transport.known.add('b3');
      client.retryFailedJoins();
      await pumpEventQueue();
      expect(transport.rooms, {'b3'});
      client.retryFailedJoins();
      await pumpEventQueue();
      expect(transport.joins, hasLength(3));
    });

    test('leaves a room released while its join was in flight', () async {
      client.start();
      await pumpEventQueue();
      transport.holdJoins = Completer();
      client.watch('b1')();
      transport.holdJoins!.complete();
      await pumpEventQueue();
      expect(transport.leaves, ['b1']);
      expect(transport.rooms, isEmpty);
    });

    test('ignores the transport after stop', () async {
      client.start();
      await pumpEventQueue();
      await client.stop();
      expect(transport.connected, isFalse);
      syncs = 0;
      transport.serverEvent();
      await pumpEventQueue();
      expect(syncs, 0);
    });
  });

  test('the board stream keeps the board room joined', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final events = <String>[];
    final repo = DriftBoardsRepository(
      db,
      watchRoom: (id) {
        events.add('join $id');
        return () => events.add('leave $id');
      },
    );
    final subscription = repo.watchBoard('b1').listen((_) {});
    await pumpEventQueue();
    expect(events, ['join b1']);
    await subscription.cancel();
    expect(events, ['join b1', 'leave b1']);
  });

  test('a card moved on one device shows up on the other within a '
      'second', () async {
    final server = FakeSyncServer();
    final alice = Device(server, 'alice');
    final bob = Device(server, 'bob');
    addTearDown(() async {
      await alice.close();
      await bob.close();
    });
    await alice.join();
    await bob.join();
    final created = await alice.repo.createBoard(
      workspaceId: ws,
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Done'],
    );
    final board = (await alice.board(created.id))!;
    final card = await alice.repo.createCard(
      board.columns.first.column.id,
      'Intro',
    );
    await alice.sync();
    await bob.sync();

    // Bob has the board open; the periodic sync is a minute away.
    bob.realtime.start();
    final onBob = bob.repo.watchBoard(board.board.id);
    final moved = onBob.firstWhere(
      (b) => b!.columns.last.cards.any((c) => c.id == card.id),
    );
    await pumpEventQueue();
    expect(bob.transport.rooms, {board.board.id});

    final watch = Stopwatch()..start();
    await alice.repo.moveCard(
      card.id,
      toColumnId: board.columns.last.column.id,
      toIndex: 0,
    );
    await moved.timeout(const Duration(seconds: 1));
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });
}
