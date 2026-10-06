import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flowboard/core/db/tables.dart';

export 'package:flowboard/core/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Boards,
    BoardColumns,
    Cards,
    ChecklistItems,
    Comments,
    Outbox,
    CachedWorkspaces,
    CachedMembers,
    LocalMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'flowboard'));

  static const _ownerKey = 'ownerUserId';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX idx_columns_board ON board_columns (board_id, position)',
      );
      await customStatement(
        'CREATE INDEX idx_cards_column ON cards (column_id, position)',
      );
      await customStatement('CREATE INDEX idx_cards_board ON cards (board_id)');
      await customStatement(
        'CREATE INDEX idx_checklist_card '
        'ON checklist_items (card_id, position)',
      );
      await customStatement(
        'CREATE INDEX idx_boards_workspace ON boards (workspace_id)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Local data belongs to one account. Signing in as someone else wipes it;
  /// the same user signing back in keeps (possibly unsynced) data.
  Future<void> claimFor(String userId) => transaction(() async {
    final owner = await (select(
      localMeta,
    )..where((m) => m.key.equals(_ownerKey))).getSingleOrNull();
    if (owner?.value == userId) return;
    if (owner != null) await _wipe();
    await into(localMeta).insertOnConflictUpdate(
      LocalMetaCompanion.insert(key: _ownerKey, value: userId),
    );
  });

  Future<void> _wipe() async {
    // Children first because of foreign keys.
    for (final table in <TableInfo<Table, Object?>>[
      comments,
      checklistItems,
      cards,
      boardColumns,
      boards,
      outbox,
      cachedMembers,
      cachedWorkspaces,
      localMeta,
    ]) {
      await delete(table).go();
    }
  }
}
