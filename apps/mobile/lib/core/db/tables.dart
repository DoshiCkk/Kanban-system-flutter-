import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flowboard/features/boards/domain/board_models.dart'
    show CardPriority;

export 'package:flowboard/features/boards/domain/board_models.dart'
    show CardPriority;

/// Fields shared by every synced entity (see docs/sync.md):
/// client-generated UUID v4 id, timestamps, soft delete and a server-owned
/// version (0 = never acknowledged by the server).
///
/// Synced tables have no foreign keys: pulled pages may deliver a child
/// before its parent. Queries join through live parents instead.
mixin SyncedEntity on Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stores `List<String>` as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

@DataClassName('BoardRow')
class Boards extends Table with SyncedEntity {
  TextColumn get workspaceId => text()();

  TextColumn get title => text()();

  TextColumn get templateKey => text().nullable()();
}

@DataClassName('ColumnRow')
class BoardColumns extends Table with SyncedEntity {
  TextColumn get boardId => text()();

  TextColumn get title => text()();

  /// Fractional index key, see core/ordering/fractional_index.dart.
  TextColumn get position => text()();

  /// Stored for v2; not enforced in MVP.
  IntColumn get wipLimit => integer().nullable()();
}

@DataClassName('CardRow')
class Cards extends Table with SyncedEntity {
  TextColumn get columnId => text()();

  /// Denormalized from the column so a board loads with one query.
  TextColumn get boardId => text()();

  TextColumn get title => text()();

  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get assigneeId => text().nullable()();

  DateTimeColumn get dueDate => dateTime().nullable()();

  TextColumn get priority => textEnum<CardPriority>().withDefault(
    Constant(CardPriority.medium.name),
  )();

  TextColumn get labels => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  TextColumn get position => text()();
}

@DataClassName('ChecklistItemRow')
class ChecklistItems extends Table with SyncedEntity {
  TextColumn get cardId => text()();

  TextColumn get content => text().named('text')();

  BoolColumn get done => boolean().withDefault(const Constant(false))();

  TextColumn get position => text()();
}

/// Filled in phase 5 (comments and @mentions).
@DataClassName('CommentRow')
class Comments extends Table with SyncedEntity {
  TextColumn get cardId => text()();

  TextColumn get authorId => text()();

  TextColumn get content => text().named('text')();

  TextColumn get mentions => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
}

// Attachments are out of MVP. They will be a synced `attachments` table
// (id, cardId, fileName, mimeType, size, remoteUrl, localPath) — no schema
// changes to cards are needed.

/// Pending local mutations, pushed by the SyncEngine (docs/sync.md §3).
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get opId => text()();

  TextColumn get entity => text()();

  TextColumn get entityId => text()();

  TextColumn get operation => text()();

  /// JSON object.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

/// Read-through cache of the workspaces list (server is the source of truth).
@DataClassName('WorkspaceCacheRow')
class CachedWorkspaces extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get role => text()();

  IntColumn get memberCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MemberCacheRow')
class CachedMembers extends Table {
  TextColumn get workspaceId => text()();

  TextColumn get userId => text()();

  TextColumn get name => text()();

  TextColumn get email => text()();

  TextColumn get avatarUrl => text().nullable()();

  TextColumn get role => text()();

  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {workspaceId, userId};
}

/// Small key/value store for local bookkeeping (owner user, sync cursor).
@DataClassName('MetaRow')
class LocalMeta extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
