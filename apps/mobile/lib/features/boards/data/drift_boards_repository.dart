import 'package:drift/drift.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/ordering/fractional_index.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:uuid/uuid.dart';

/// Drift-backed implementation of both board and card repositories.
///
/// Deletes are soft (`deletedAt`) so they can be synced as tombstones.
/// Ordering uses fractional index keys with `id` as a tie-breaker.
class DriftBoardsRepository implements BoardsRepository, CardRepository {
  DriftBoardsRepository(
    this._db, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  DateTime _now() => _clock().toUtc();

  String _newId() => _uuid.v4();

  // ---------------------------------------------------------------- boards

  @override
  Stream<List<Board>> watchBoards(String workspaceId) {
    final query = _db.select(_db.boards)
      ..where((b) => b.workspaceId.equals(workspaceId) & b.deletedAt.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toBoard).toList());
  }

  @override
  Future<Board> createBoard({
    required String workspaceId,
    required String title,
    required BoardTemplate template,
    required List<String> columnTitles,
  }) => _db.transaction(() async {
    final now = _now();
    final board = BoardsCompanion.insert(
      id: _newId(),
      workspaceId: workspaceId,
      title: title.trim(),
      templateKey: Value(template.name),
      createdAt: now,
      updatedAt: now,
    );
    final row = await _db.into(_db.boards).insertReturning(board);
    final keys = generateNKeysBetween(null, null, columnTitles.length);
    for (var i = 0; i < columnTitles.length; i++) {
      await _db
          .into(_db.boardColumns)
          .insert(
            BoardColumnsCompanion.insert(
              id: _newId(),
              boardId: row.id,
              title: columnTitles[i],
              position: keys[i],
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    return _toBoard(row);
  });

  @override
  Future<void> renameBoard(String boardId, String title) =>
      (_db.update(_db.boards)..where((b) => b.id.equals(boardId))).write(
        BoardsCompanion(title: Value(title.trim()), updatedAt: Value(_now())),
      );

  @override
  Future<void> deleteBoard(String boardId) =>
      (_db.update(_db.boards)..where((b) => b.id.equals(boardId))).write(
        BoardsCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
      );

  @override
  Stream<BoardContent?> watchBoard(String boardId) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.boards,
          _db.boardColumns,
          _db.cards,
          _db.checklistItems,
        },
      )
      .watch()
      .asyncMap((_) => _loadBoard(boardId))
      .distinct();

  Future<BoardContent?> _loadBoard(String boardId) async {
    final board =
        await (_db.select(_db.boards)
              ..where((b) => b.id.equals(boardId) & b.deletedAt.isNull()))
            .getSingleOrNull();
    if (board == null) return null;

    final columns = await _liveColumns(boardId);
    final cards =
        await (_db.select(_db.cards)
              ..where((c) => c.boardId.equals(boardId) & c.deletedAt.isNull())
              ..orderBy([
                (c) => OrderingTerm.asc(c.position),
                (c) => OrderingTerm.asc(c.id),
              ]))
            .get();

    final counts = <String, (int done, int total)>{};
    final rows = await _db
        .customSelect(
          'SELECT ci.card_id AS card_id, COUNT(*) AS total, '
          'SUM(ci.done) AS done FROM checklist_items ci '
          'JOIN cards c ON c.id = ci.card_id '
          'WHERE c.board_id = ? AND ci.deleted_at IS NULL '
          'GROUP BY ci.card_id',
          variables: [Variable.withString(boardId)],
          readsFrom: {_db.checklistItems, _db.cards},
        )
        .get();
    for (final row in rows) {
      counts[row.read<String>('card_id')] = (
        row.read<int>('done'),
        row.read<int>('total'),
      );
    }

    final byColumn = <String, List<CardSummary>>{};
    for (final card in cards) {
      final (done, total) = counts[card.id] ?? (0, 0);
      byColumn
          .putIfAbsent(card.columnId, () => [])
          .add(_toSummary(card, done, total));
    }
    return BoardContent(
      board: _toBoard(board),
      columns: [
        for (final column in columns)
          ColumnWithCards(
            column: _toColumn(column),
            cards: byColumn[column.id] ?? const [],
          ),
      ],
    );
  }

  // --------------------------------------------------------------- columns

  @override
  Future<BoardColumn> addColumn(String boardId, String title) =>
      _db.transaction(() async {
        final columns = await _liveColumns(boardId);
        final now = _now();
        final row = await _db
            .into(_db.boardColumns)
            .insertReturning(
              BoardColumnsCompanion.insert(
                id: _newId(),
                boardId: boardId,
                title: title.trim(),
                position: generateKeyBetween(
                  columns.isEmpty ? null : columns.last.position,
                  null,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return _toColumn(row);
      });

  @override
  Future<void> renameColumn(String columnId, String title) =>
      (_db.update(_db.boardColumns)..where((c) => c.id.equals(columnId))).write(
        BoardColumnsCompanion(
          title: Value(title.trim()),
          updatedAt: Value(_now()),
        ),
      );

  @override
  Future<void> deleteColumn(String columnId) => _db.transaction(() async {
    final now = _now();
    await (_db.update(
      _db.boardColumns,
    )..where((c) => c.id.equals(columnId))).write(
      BoardColumnsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (_db.update(_db.cards)
          ..where((c) => c.columnId.equals(columnId) & c.deletedAt.isNull()))
        .write(CardsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  });

  Future<List<ColumnRow>> _liveColumns(String boardId) =>
      (_db.select(_db.boardColumns)
            ..where((c) => c.boardId.equals(boardId) & c.deletedAt.isNull())
            ..orderBy([
              (c) => OrderingTerm.asc(c.position),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .get();

  // ----------------------------------------------------------------- cards

  @override
  Future<CardSummary> createCard(String columnId, String title) =>
      _db.transaction(() async {
        final column = await (_db.select(
          _db.boardColumns,
        )..where((c) => c.id.equals(columnId))).getSingle();
        final siblings = await _liveCards(columnId);
        final now = _now();
        final row = await _db
            .into(_db.cards)
            .insertReturning(
              CardsCompanion.insert(
                id: _newId(),
                columnId: columnId,
                boardId: column.boardId,
                title: title.trim(),
                position: generateKeyBetween(
                  siblings.isEmpty ? null : siblings.last.position,
                  null,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return _toSummary(row, 0, 0);
      });

  @override
  Future<void> moveCard(
    String cardId, {
    required String toColumnId,
    required int toIndex,
  }) => _db.transaction(() async {
    final card = await (_db.select(
      _db.cards,
    )..where((c) => c.id.equals(cardId))).getSingle();
    var others = (await _liveCards(
      toColumnId,
    )).where((c) => c.id != cardId).toList();
    final index = toIndex.clamp(0, others.length);

    String? before() => index == 0 ? null : others[index - 1].position;
    String? after() => index == others.length ? null : others[index].position;

    final b = before();
    final a = after();
    final alreadyThere =
        card.columnId == toColumnId &&
        (b == null || b.compareTo(card.position) < 0) &&
        (a == null || card.position.compareTo(a) < 0);
    if (alreadyThere) return;

    if (b != null && a != null && b.compareTo(a) >= 0) {
      // Duplicate keys (e.g. concurrent inserts on two devices): spread the
      // column out again, then compute the slot.
      others = await _rebalance(others);
    }

    await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        columnId: Value(toColumnId),
        position: Value(generateKeyBetween(before(), after())),
        updatedAt: Value(_now()),
      ),
    );
  });

  Future<List<CardRow>> _rebalance(List<CardRow> cards) async {
    final keys = generateNKeysBetween(null, null, cards.length);
    final now = _now();
    final result = <CardRow>[];
    for (var i = 0; i < cards.length; i++) {
      await (_db.update(
        _db.cards,
      )..where((c) => c.id.equals(cards[i].id))).write(
        CardsCompanion(position: Value(keys[i]), updatedAt: Value(now)),
      );
      result.add(cards[i].copyWith(position: keys[i]));
    }
    return result;
  }

  Future<List<CardRow>> _liveCards(String columnId) =>
      (_db.select(_db.cards)
            ..where((c) => c.columnId.equals(columnId) & c.deletedAt.isNull())
            ..orderBy([
              (c) => OrderingTerm.asc(c.position),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .get();

  @override
  Stream<CardDetails?> watchCard(String cardId) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.boards,
          _db.boardColumns,
          _db.cards,
          _db.checklistItems,
        },
      )
      .watch()
      .asyncMap((_) => _loadCard(cardId))
      .distinct();

  Future<CardDetails?> _loadCard(String cardId) async {
    final card =
        await (_db.select(_db.cards)
              ..where((c) => c.id.equals(cardId) & c.deletedAt.isNull()))
            .getSingleOrNull();
    if (card == null) return null;
    final board = await (_db.select(
      _db.boards,
    )..where((b) => b.id.equals(card.boardId))).getSingle();
    if (board.deletedAt != null) return null;
    final columns = await _liveColumns(card.boardId);
    if (!columns.any((c) => c.id == card.columnId)) return null;
    final checklist =
        await (_db.select(_db.checklistItems)
              ..where((i) => i.cardId.equals(cardId) & i.deletedAt.isNull())
              ..orderBy([
                (i) => OrderingTerm.asc(i.position),
                (i) => OrderingTerm.asc(i.id),
              ]))
            .get();

    return CardDetails(
      id: card.id,
      boardId: card.boardId,
      workspaceId: board.workspaceId,
      columnId: card.columnId,
      title: card.title,
      description: card.description,
      priority: card.priority,
      labels: card.labels,
      dueDate: card.dueDate,
      assigneeId: card.assigneeId,
      columns: columns.map(_toColumn).toList(),
      checklist: [
        for (final item in checklist)
          ChecklistItem(
            id: item.id,
            text: item.content,
            done: item.done,
            position: item.position,
          ),
      ],
    );
  }

  @override
  Future<void> updateCard(String cardId, CardPatch patch) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(
          title: patch.title == null
              ? const Value.absent()
              : Value(patch.title!.trim()),
          description: Value.absentIfNull(patch.description),
          priority: Value.absentIfNull(patch.priority),
          labels: Value.absentIfNull(patch.labels),
          dueDate: patch.clearDueDate
              ? const Value(null)
              : Value.absentIfNull(patch.dueDate),
          assigneeId: patch.clearAssignee
              ? const Value(null)
              : Value.absentIfNull(patch.assigneeId),
          updatedAt: Value(_now()),
        ),
      );

  @override
  Future<void> deleteCard(String cardId) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
      );

  // ------------------------------------------------------------- checklist

  @override
  Future<ChecklistItem> addChecklistItem(String cardId, String text) =>
      _db.transaction(() async {
        final last =
            await (_db.select(_db.checklistItems)
                  ..where(
                    (i) => i.cardId.equals(cardId) & i.deletedAt.isNull(),
                  )
                  ..orderBy([(i) => OrderingTerm.desc(i.position)])
                  ..limit(1))
                .getSingleOrNull();
        final now = _now();
        final row = await _db
            .into(_db.checklistItems)
            .insertReturning(
              ChecklistItemsCompanion.insert(
                id: _newId(),
                cardId: cardId,
                content: text.trim(),
                position: generateKeyBetween(last?.position, null),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return ChecklistItem(
          id: row.id,
          text: row.content,
          done: row.done,
          position: row.position,
        );
      });

  @override
  Future<void> updateChecklistItem(String itemId, {String? text, bool? done}) =>
      (_db.update(_db.checklistItems)..where((i) => i.id.equals(itemId))).write(
        ChecklistItemsCompanion(
          content: text == null ? const Value.absent() : Value(text.trim()),
          done: Value.absentIfNull(done),
          updatedAt: Value(_now()),
        ),
      );

  @override
  Future<void> deleteChecklistItem(String itemId) =>
      (_db.update(_db.checklistItems)..where((i) => i.id.equals(itemId))).write(
        ChecklistItemsCompanion(
          deletedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );

  // --------------------------------------------------------------- mapping

  Board _toBoard(BoardRow row) => Board(
    id: row.id,
    workspaceId: row.workspaceId,
    title: row.title,
    templateKey: row.templateKey,
    updatedAt: row.updatedAt,
  );

  BoardColumn _toColumn(ColumnRow row) => BoardColumn(
    id: row.id,
    boardId: row.boardId,
    title: row.title,
    position: row.position,
    wipLimit: row.wipLimit,
  );

  CardSummary _toSummary(CardRow row, int done, int total) => CardSummary(
    id: row.id,
    columnId: row.columnId,
    title: row.title,
    priority: row.priority,
    position: row.position,
    labels: row.labels,
    dueDate: row.dueDate,
    assigneeId: row.assigneeId,
    checklistDone: done,
    checklistTotal: total,
  );
}
