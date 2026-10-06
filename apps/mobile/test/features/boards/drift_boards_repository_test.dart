import 'dart:io';

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

  Future<BoardContent> createBasic() async {
    final board = await repo.createBoard(
      workspaceId: 'w1',
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Doing', 'Done'],
    );
    return (await repo.watchBoard(board.id).first)!;
  }

  List<String> titles(BoardContent content, int column) =>
      content.columns[column].cards.map((c) => c.title).toList();

  test('creates a board from a template with ordered columns', () async {
    final content = await createBasic();
    expect(content.board.templateKey, 'basic');
    expect(content.columns.map((c) => c.column.title), [
      'To do',
      'Doing',
      'Done',
    ]);
    expect(content.columns.every((c) => c.cards.isEmpty), isTrue);
  });

  test('appends cards and moves them across columns', () async {
    final content = await createBasic();
    final todo = content.columns[0].column.id;
    final doing = content.columns[1].column.id;
    final a = await repo.createCard(todo, 'A');
    await repo.createCard(todo, 'B');
    await repo.createCard(todo, 'C');

    await repo.moveCard(a.id, toColumnId: doing, toIndex: 0);
    var board = (await repo.watchBoard(content.board.id).first)!;
    expect(titles(board, 0), ['B', 'C']);
    expect(titles(board, 1), ['A']);

    // Back between B and C.
    await repo.moveCard(a.id, toColumnId: todo, toIndex: 1);
    board = (await repo.watchBoard(content.board.id).first)!;
    expect(titles(board, 0), ['B', 'A', 'C']);
  });

  test('moving a card rewrites only that card', () async {
    final content = await createBasic();
    final todo = content.columns[0].column.id;
    final cards = [
      for (final t in ['A', 'B', 'C', 'D']) await repo.createCard(todo, t),
    ];
    final before = {
      for (final row in await db.select(db.cards).get()) row.id: row.position,
    };

    await repo.moveCard(cards[3].id, toColumnId: todo, toIndex: 0);

    final after = {
      for (final row in await db.select(db.cards).get()) row.id: row.position,
    };
    final changed = after.keys.where((id) => after[id] != before[id]);
    expect(changed, [cards[3].id]);
    final board = (await repo.watchBoard(content.board.id).first)!;
    expect(titles(board, 0), ['D', 'A', 'B', 'C']);
  });

  test('rebalances when neighbours share a key (sync collision)', () async {
    final content = await createBasic();
    final todo = content.columns[0].column.id;
    final a = await repo.createCard(todo, 'A');
    final b = await repo.createCard(todo, 'B');
    final c = await repo.createCard(todo, 'C');
    // Simulate two devices that inserted with the same key.
    await (db.update(db.cards)..where((r) => r.id.equals(b.id))).write(
      CardsCompanion(position: Value(a.position)),
    );

    await repo.moveCard(c.id, toColumnId: todo, toIndex: 1);

    final board = (await repo.watchBoard(content.board.id).first)!;
    expect(board.columns[0].cards[1].id, c.id);
    final keys = board.columns[0].cards.map((x) => x.position).toList();
    expect(keys.toSet(), hasLength(3));
    expect(keys, [...keys]..sort());
  });

  test('watchBoard emits on changes and checklist counts', () async {
    final content = await createBasic();
    final todo = content.columns[0].column.id;
    final emissions = <BoardContent?>[];
    final sub = repo.watchBoard(content.board.id).listen(emissions.add);

    final card = await repo.createCard(todo, 'Task');
    final item = await repo.addChecklistItem(card.id, 'step 1');
    await repo.addChecklistItem(card.id, 'step 2');
    await repo.updateChecklistItem(item.id, done: true);
    await pumpEventQueue();

    final last = emissions.last!.columns[0].cards.single;
    expect(last.checklistDone, 1);
    expect(last.checklistTotal, 2);
    await sub.cancel();
  });

  test('soft-deleting a column hides it and its cards', () async {
    final content = await createBasic();
    final todo = content.columns[0].column.id;
    await repo.createCard(todo, 'A');
    await repo.deleteColumn(todo);

    final board = (await repo.watchBoard(content.board.id).first)!;
    expect(board.columns.map((c) => c.column.title), ['Doing', 'Done']);
    final rows = await db.select(db.cards).get();
    expect(rows.single.deletedAt, isNotNull);
  });

  test('card details: patch fields, next column, delete', () async {
    final content = await createBasic();
    final card = await repo.createCard(content.columns[0].column.id, 'A');
    await repo.updateCard(
      card.id,
      CardPatch(
        description: 'Write chapter 2',
        priority: CardPriority.high,
        labels: const ['thesis'],
        dueDate: DateTime.utc(2026, 10, 10),
        assigneeId: 'u1',
      ),
    );
    var details = (await repo.watchCard(card.id).first)!;
    expect(details.priority, CardPriority.high);
    expect(details.labels, ['thesis']);
    expect(details.workspaceId, 'w1');
    expect(details.nextColumn?.title, 'Doing');

    await repo.updateCard(
      card.id,
      const CardPatch(clearDueDate: true, clearAssignee: true),
    );
    details = (await repo.watchCard(card.id).first)!;
    expect(details.dueDate, isNull);
    expect(details.assigneeId, isNull);
    expect(details.description, 'Write chapter 2');

    await repo.deleteCard(card.id);
    expect(await repo.watchCard(card.id).first, isNull);
  });

  test('data survives closing and reopening the database file', () async {
    final dir = await Directory.systemTemp.createTemp('flowboard_test');
    final file = File('${dir.path}/db.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    var fileDb = AppDatabase(NativeDatabase(file));
    var fileRepo = DriftBoardsRepository(fileDb);
    final board = await fileRepo.createBoard(
      workspaceId: 'w1',
      title: 'Persistent',
      template: BoardTemplate.basic,
      columnTitles: const ['A', 'B', 'C'],
    );
    final content = (await fileRepo.watchBoard(board.id).first)!;
    await fileRepo.createCard(content.columns[1].column.id, 'Survivor');
    await fileDb.close();

    fileDb = AppDatabase(NativeDatabase(file));
    fileRepo = DriftBoardsRepository(fileDb);
    final reopened = (await fileRepo.watchBoard(board.id).first)!;
    expect(reopened.board.title, 'Persistent');
    expect(reopened.columns[1].cards.single.title, 'Survivor');
    await fileDb.close();
  });
}
