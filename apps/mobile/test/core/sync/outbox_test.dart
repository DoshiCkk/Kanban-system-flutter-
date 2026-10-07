import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBoardsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBoardsRepository(db);
  });
  tearDown(() => db.close());

  Future<List<(String, String, Map<String, dynamic>)>> ops() async => [
    for (final op in await (db.select(
      db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.createdAt)])).get())
      (
        op.entity,
        op.operation,
        jsonDecode(op.payload) as Map<String, dynamic>,
      ),
  ];

  Future<void> clearOutbox() => db.delete(db.outbox).go();

  Future<BoardContent> board() async {
    final b = await repo.createBoard(
      workspaceId: 'w1',
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Doing', 'Done'],
    );
    return (await repo.watchBoard(b.id).first)!;
  }

  test('creating a board queues the board and its columns', () async {
    await board();
    final queued = await ops();
    expect(queued.map((o) => '${o.$1}:${o.$2}'), [
      'board:create',
      'column:create',
      'column:create',
      'column:create',
    ]);
    expect(queued.first.$3, containsPair('workspaceId', 'w1'));
    expect(queued[1].$3.keys, {'boardId', 'title', 'position', 'createdAt'});
  });

  test('a move queues one update with column and position only', () async {
    final content = await board();
    final card = await repo.createCard(content.columns[0].column.id, 'A');
    await clearOutbox();

    await repo.moveCard(
      card.id,
      toColumnId: content.columns[1].column.id,
      toIndex: 0,
    );
    final queued = await ops();
    expect(queued, hasLength(1));
    expect(queued.single.$1, 'card');
    expect(queued.single.$2, 'update');
    expect(queued.single.$3.keys, {'columnId', 'position'});
  });

  test('card patches send only changed fields; clears send null', () async {
    final content = await board();
    final card = await repo.createCard(content.columns[0].column.id, 'A');
    await clearOutbox();

    await repo.updateCard(
      card.id,
      const CardPatch(title: ' Renamed ', clearDueDate: true),
    );
    await repo.updateCard(card.id, CardPatch(dueDate: DateTime(2026, 12)));
    final queued = await ops();
    expect(queued[0].$3, {'title': 'Renamed', 'dueDate': null});
    expect(queued[1].$3.keys, {'dueDate'});
  });

  test('deleting a column queues only the column', () async {
    final content = await board();
    final column = content.columns[0].column.id;
    await repo.createCard(column, 'A');
    await repo.createCard(column, 'B');
    await clearOutbox();

    await repo.deleteColumn(column);
    expect((await ops()).map((o) => '${o.$1}:${o.$2}'), ['column:delete']);
  });

  test('checklist edits are queued', () async {
    final content = await board();
    final card = await repo.createCard(content.columns[0].column.id, 'A');
    await clearOutbox();

    final item = await repo.addChecklistItem(card.id, 'Draft');
    await repo.updateChecklistItem(item.id, done: true);
    await repo.deleteChecklistItem(item.id);
    final queued = await ops();
    expect(queued.map((o) => o.$2), ['create', 'update', 'delete']);
    expect(queued[1].$3, {'done': true});
  });

  test('row change and outbox op commit or fail together', () async {
    final content = await board();
    await db.customStatement('DROP TABLE outbox');

    await expectLater(
      repo.renameBoard(content.board.id, 'Renamed'),
      throwsA(isA<Object>()),
    );
    final row = await (db.select(
      db.boards,
    )..where((b) => b.id.equals(content.board.id))).getSingle();
    expect(row.title, 'Diploma');
  });
}
