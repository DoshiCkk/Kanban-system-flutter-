import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/sync_api.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBoardsRepository repo;
  late SyncStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBoardsRepository(db);
    store = SyncStore(db);
  });
  tearDown(() => db.close());

  const ws = 'w1';
  const t0 = '2026-10-07T10:00:00.000Z';

  PullPage page({
    List<WireRow> boards = const [],
    List<WireRow> columns = const [],
    List<WireRow> cards = const [],
    String cursor = '10',
  }) => PullPage(
    rows: {
      'boards': boards,
      'columns': columns,
      'cards': cards,
      'checklistItems': const [],
      'comments': const [],
    },
    cursor: cursor,
    hasMore: false,
  );

  WireRow boardRow(String id, {String title = 'Server', String? deletedAt}) => {
    'id': id,
    'workspaceId': ws,
    'title': title,
    'templateKey': null,
    'createdAt': t0,
    'updatedAt': t0,
    'deletedAt': deletedAt,
    'version': 3,
  };

  WireRow cardRow(
    String id, {
    required String boardId,
    required String columnId,
    String title = 'Server title',
    String description = 'Server description',
  }) => {
    'id': id,
    'boardId': boardId,
    'columnId': columnId,
    'title': title,
    'description': description,
    'assigneeId': null,
    'dueDate': null,
    'priority': 'high',
    'labels': ['api'],
    'position': 'a0',
    'createdAt': t0,
    'updatedAt': t0,
    'deletedAt': null,
    'version': 5,
  };

  test('inserts pulled rows even before their parents arrive', () async {
    await store.applyPull(
      ws,
      page(
        cards: [cardRow('c1', boardId: 'b1', columnId: 'col1')],
        cursor: '7',
      ),
    );
    await store.applyPull(
      ws,
      page(
        boards: [boardRow('b1')],
        columns: [
          {
            'id': 'col1',
            'boardId': 'b1',
            'title': 'To do',
            'position': 'a0',
            'wipLimit': null,
            'createdAt': t0,
            'updatedAt': t0,
            'deletedAt': null,
            'version': 1,
          },
        ],
        cursor: '9',
      ),
    );

    final content = (await repo.watchBoard('b1').first)!;
    expect(content.columns.single.cards.single.title, 'Server title');
    expect(content.columns.single.cards.single.priority, CardPriority.high);
    expect(await store.cursor(ws), '9');
  });

  test('keeps fields with pending local ops and takes the rest', () async {
    final board = await repo.createBoard(
      workspaceId: ws,
      title: 'Local',
      template: BoardTemplate.basic,
      columnTitles: const ['To do'],
    );
    final column = (await repo.watchBoard(board.id).first)!.columns.single;
    final card = await repo.createCard(column.column.id, 'Draft');
    await db.delete(db.outbox).go(); // Pretend the creates were pushed.

    await repo.updateCard(card.id, const CardPatch(title: 'Local title'));
    await store.applyPull(
      ws,
      page(
        cards: [
          cardRow(card.id, boardId: board.id, columnId: column.column.id),
        ],
      ),
    );

    final details = (await repo.watchCard(card.id).first)!;
    expect(details.title, 'Local title');
    expect(details.description, 'Server description');
    expect(details.labels, ['api']);
    expect(await store.pendingCount(), 1);
  });

  test('a tombstone deletes the row and voids its pending ops', () async {
    final board = await repo.createBoard(
      workspaceId: ws,
      title: 'Local',
      template: BoardTemplate.empty,
      columnTitles: const [],
    );
    await repo.renameBoard(board.id, 'Renamed offline');

    await store.applyPull(
      ws,
      page(boards: [boardRow(board.id, deletedAt: t0)]),
    );

    expect(await repo.watchBoard(board.id).first, isNull);
    final ops = await (db.select(
      db.outbox,
    )..where((o) => o.entityId.equals(board.id))).get();
    expect(ops, isEmpty);
  });

  test('a pending local delete survives a pull of the live row', () async {
    final board = await repo.createBoard(
      workspaceId: ws,
      title: 'Local',
      template: BoardTemplate.empty,
      columnTitles: const [],
    );
    await db.delete(db.outbox).go();
    await repo.deleteBoard(board.id);

    await store.applyPull(ws, page(boards: [boardRow(board.id)]));
    expect(await repo.watchBoard(board.id).first, isNull);
  });

  test('forgetting a workspace drops its rows, ops and cursor', () async {
    final board = await repo.createBoard(
      workspaceId: ws,
      title: 'Gone',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Done'],
    );
    await repo.createBoard(
      workspaceId: 'w2',
      title: 'Kept',
      template: BoardTemplate.empty,
      columnTitles: const [],
    );
    await store.applyPull(ws, page(cursor: '42'));

    await store.forgetWorkspace(ws);

    expect(await repo.watchBoard(board.id).first, isNull);
    expect(await db.select(db.boardColumns).get(), isEmpty);
    expect(await store.pendingCount(), 1); // Only the w2 board.
    expect(await store.cursor(ws), '0');
  });
}
