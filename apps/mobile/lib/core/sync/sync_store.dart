import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/outbox.dart';
import 'package:flowboard/core/sync/sync_api.dart';

/// Local side of sync: reads the outbox and applies pulled rows with the
/// rebase rules of docs/sync.md §6. Only the SyncEngine uses it.
class SyncStore {
  SyncStore(this._db);

  final AppDatabase _db;

  static const _cursorPrefix = 'sync.cursor.';

  // ---------------------------------------------------------------- outbox

  Selectable<int> _pendingCount() {
    final count = _db.outbox.opId.count();
    return (_db.selectOnly(
      _db.outbox,
    )..addColumns([count])).map((row) => row.read(count) ?? 0);
  }

  Stream<int> watchPendingCount() => _pendingCount().watchSingle();

  Future<int> pendingCount() => _pendingCount().getSingle();

  /// Oldest ops first; `rowid` breaks ties of equal timestamps.
  Future<List<OutboxRow>> nextBatch(int limit) => _db
      .customSelect(
        'SELECT * FROM outbox ORDER BY created_at, rowid LIMIT ?',
        variables: [Variable.withInt(limit)],
        readsFrom: {_db.outbox},
      )
      .asyncMap((row) => _db.outbox.mapFromRow(row))
      .get();

  Future<void> completeOps(Iterable<String> opIds) =>
      (_db.delete(_db.outbox)..where((o) => o.opId.isIn(opIds))).go();

  Future<void> markAttempted(Iterable<String> opIds) => _db.customUpdate(
    'UPDATE outbox SET attempts = attempts + 1 '
    'WHERE op_id IN (${List.filled(opIds.length, '?').join(', ')})',
    variables: [for (final id in opIds) Variable.withString(id)],
    updates: {_db.outbox},
  );

  /// The server refused to create this row, so it will never be pulled:
  /// hide it locally.
  Future<void> discardCreate(String entity, String entityId) async {
    final table = _tableOf(entity);
    if (table == null) return;
    await _db.customUpdate(
      'UPDATE ${table.actualTableName} SET deleted_at = ? WHERE id = ?',
      variables: [
        Variable.withDateTime(DateTime.now().toUtc()),
        Variable.withString(entityId),
      ],
      updates: {table},
    );
  }

  // ---------------------------------------------------------------- cursors

  Selectable<String> _workspaceIds() => (_db.select(
    _db.cachedWorkspaces,
  )..orderBy([(w) => OrderingTerm.asc(w.id)])).map((w) => w.id);

  Stream<List<String>> watchWorkspaceIds() => _workspaceIds().watch();

  Future<List<String>> workspaceIds() => _workspaceIds().get();

  Future<String> cursor(String workspaceId) async {
    final key = '$_cursorPrefix$workspaceId';
    final row = await (_db.select(
      _db.localMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row?.value ?? '0';
  }

  /// Forces a full pull, which restores server truth after a rejected op.
  Future<void> resetCursors() => (_db.delete(
    _db.localMeta,
  )..where((m) => m.key.like('$_cursorPrefix%'))).go();

  // ------------------------------------------------------------------ pull

  Future<void> applyPull(String workspaceId, PullPage page) =>
      _db.transaction(() async {
        final pending = await _pendingFields();
        final dropOps = <(String, String)>[];
        for (final kind in PullPage.kinds) {
          final entity = _entityOfKind[kind]!;
          for (final row in page.rows[kind]!) {
            final id = row['id'] as String;
            final key = (entity, id);
            if (row['deletedAt'] != null) {
              // Delete wins: local intent for this row is void.
              dropOps.add(key);
              await _upsert(entity, row, const {});
            } else {
              await _upsert(entity, row, pending[key] ?? const {});
            }
          }
        }
        for (final (entity, id) in dropOps) {
          await (_db.delete(_db.outbox)
                ..where((o) => o.entity.equals(entity) & o.entityId.equals(id)))
              .go();
        }
        await _db
            .into(_db.localMeta)
            .insertOnConflictUpdate(
              LocalMetaCompanion.insert(
                key: '$_cursorPrefix$workspaceId',
                value: page.cursor,
              ),
            );
      });

  /// Wire keys changed by not-yet-pushed ops, per (entity, id).
  /// A pending delete protects `deletedAt`.
  Future<Map<(String, String), Set<String>>> _pendingFields() async {
    final result = <(String, String), Set<String>>{};
    for (final op in await _db.select(_db.outbox).get()) {
      final keys = result.putIfAbsent((op.entity, op.entityId), () => {});
      if (op.operation == SyncOperation.delete.name) {
        keys.add('deletedAt');
      } else {
        keys.addAll((jsonDecode(op.payload) as Map<String, dynamic>).keys);
      }
    }
    return result;
  }

  /// Writes a server row, keeping local values for [keep] (wire keys).
  Future<void> _upsert(String entity, WireRow row, Set<String> keep) async {
    Value<T> v<T>(String key, T value) =>
        keep.contains(key) ? const Value.absent() : Value(value);

    DateTime? date(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toUtc();
    }

    final id = row['id'] as String;
    final createdAt = v('createdAt', date('createdAt')!);
    final updatedAt = Value(date('updatedAt')!);
    final deletedAt = v('deletedAt', date('deletedAt'));
    final version = Value(row['version'] as int);
    List<String> strings(String key) =>
        (row[key] as List<dynamic>? ?? const []).cast<String>();

    final (
      TableInfo<Table, Object?> table,
      Insertable<Object?> companion,
    ) = switch (entity) {
      SyncEntity.board => (
        _db.boards,
        BoardsCompanion(
          id: Value(id),
          workspaceId: Value(row['workspaceId'] as String),
          title: v('title', row['title'] as String),
          templateKey: v('templateKey', row['templateKey'] as String?),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          version: version,
        ),
      ),
      SyncEntity.column => (
        _db.boardColumns,
        BoardColumnsCompanion(
          id: Value(id),
          boardId: Value(row['boardId'] as String),
          title: v('title', row['title'] as String),
          position: v('position', row['position'] as String),
          wipLimit: v('wipLimit', row['wipLimit'] as int?),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          version: version,
        ),
      ),
      SyncEntity.card => (
        _db.cards,
        CardsCompanion(
          id: Value(id),
          boardId: Value(row['boardId'] as String),
          columnId: v('columnId', row['columnId'] as String),
          title: v('title', row['title'] as String),
          description: v('description', row['description'] as String),
          assigneeId: v('assigneeId', row['assigneeId'] as String?),
          dueDate: v('dueDate', date('dueDate')),
          priority: v(
            'priority',
            CardPriority.values.byName(row['priority'] as String),
          ),
          labels: v('labels', strings('labels')),
          position: v('position', row['position'] as String),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          version: version,
        ),
      ),
      SyncEntity.checklistItem => (
        _db.checklistItems,
        ChecklistItemsCompanion(
          id: Value(id),
          cardId: Value(row['cardId'] as String),
          content: v('text', row['text'] as String),
          done: v('done', row['done'] as bool),
          position: v('position', row['position'] as String),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          version: version,
        ),
      ),
      SyncEntity.comment => (
        _db.comments,
        CommentsCompanion(
          id: Value(id),
          cardId: Value(row['cardId'] as String),
          authorId: Value(row['authorId'] as String),
          content: v('text', row['text'] as String),
          mentions: v('mentions', strings('mentions')),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          version: version,
        ),
      ),
      _ => throw ArgumentError.value(entity, 'entity'),
    };

    if (keep.isEmpty) {
      await _db.into(table).insertOnConflictUpdate(companion);
      return;
    }
    // Pending local ops imply the row exists; update only unprotected fields.
    final updated = await (_db.update(
      table,
    )..where((t) => (t as SyncedEntity).id.equals(id))).write(companion);
    if (updated == 0) await _db.into(table).insert(companion);
  }

  TableInfo<Table, Object?>? _tableOf(String entity) => switch (entity) {
    SyncEntity.board => _db.boards,
    SyncEntity.column => _db.boardColumns,
    SyncEntity.card => _db.cards,
    SyncEntity.checklistItem => _db.checklistItems,
    SyncEntity.comment => _db.comments,
    _ => null,
  };

  static const Map<String, String> _entityOfKind = {
    'boards': SyncEntity.board,
    'columns': SyncEntity.column,
    'cards': SyncEntity.card,
    'checklistItems': SyncEntity.checklistItem,
    'comments': SyncEntity.comment,
  };

  // ---------------------------------------------------------- lost access

  /// The user is no longer a member: drop the workspace's local data,
  /// its pending ops and its cursor.
  Future<void> forgetWorkspace(String workspaceId) => _db.transaction(() async {
    const boardIds = 'SELECT id FROM boards WHERE workspace_id = ?1';
    const cardIds = 'SELECT id FROM cards WHERE board_id IN ($boardIds)';
    final w = [Variable.withString(workspaceId)];
    String ops(String entity, String ids) =>
        "DELETE FROM outbox WHERE entity = '$entity' AND entity_id IN ($ids)";
    final statements = [
      ops(
        SyncEntity.comment,
        'SELECT id FROM comments WHERE card_id IN ($cardIds)',
      ),
      ops(
        SyncEntity.checklistItem,
        'SELECT id FROM checklist_items WHERE card_id IN ($cardIds)',
      ),
      ops(SyncEntity.card, cardIds),
      ops(
        SyncEntity.column,
        'SELECT id FROM board_columns WHERE board_id IN ($boardIds)',
      ),
      ops(SyncEntity.board, boardIds),
      'DELETE FROM comments WHERE card_id IN ($cardIds)',
      'DELETE FROM checklist_items WHERE card_id IN ($cardIds)',
      'DELETE FROM cards WHERE board_id IN ($boardIds)',
      'DELETE FROM board_columns WHERE board_id IN ($boardIds)',
      'DELETE FROM boards WHERE workspace_id = ?1',
      'DELETE FROM cached_members WHERE workspace_id = ?1',
      'DELETE FROM cached_workspaces WHERE id = ?1',
    ];
    for (final sql in statements) {
      await _db.customUpdate(
        sql,
        variables: w,
        updates: {
          _db.outbox,
          _db.comments,
          _db.checklistItems,
          _db.cards,
          _db.boardColumns,
          _db.boards,
          _db.cachedMembers,
          _db.cachedWorkspaces,
        },
      );
    }
    await (_db.delete(
      _db.localMeta,
    )..where((m) => m.key.equals('$_cursorPrefix$workspaceId'))).go();
  });
}
