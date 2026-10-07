import 'dart:convert';

import 'package:flowboard/core/db/app_database.dart';
import 'package:uuid/uuid.dart';

/// Entity names on the wire (docs/sync.md §2).
abstract final class SyncEntity {
  static const board = 'board';
  static const column = 'column';
  static const card = 'card';
  static const checklistItem = 'checklistItem';
  static const comment = 'comment';
}

enum SyncOperation { create, update, delete }

/// Wire format of dates: ISO 8601 UTC.
String? wireDate(DateTime? value) => value?.toUtc().toIso8601String();

/// Records local mutations for the SyncEngine. Call it inside the same
/// Drift transaction as the row change (docs/sync.md §3).
class OutboxWriter {
  OutboxWriter(
    this._db, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// [payload] holds the changed fields only (full row for create), using
  /// wire names and values.
  Future<void> enqueue(
    String entity,
    String entityId,
    SyncOperation operation, [
    Map<String, Object?> payload = const {},
  ]) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          opId: _uuid.v4(),
          entity: entity,
          entityId: entityId,
          operation: operation.name,
          payload: jsonEncode(payload),
          createdAt: _clock().toUtc(),
        ),
      );
}
