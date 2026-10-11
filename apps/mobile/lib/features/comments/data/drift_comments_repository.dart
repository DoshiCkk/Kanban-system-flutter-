import 'package:drift/drift.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/sync/outbox.dart';
import 'package:flowboard/features/comments/domain/comment.dart';
import 'package:flowboard/features/comments/domain/comments_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Comments in Drift; every mutation writes the row and its outbox op in
/// one transaction (docs/sync.md §3).
class DriftCommentsRepository implements CommentsRepository {
  DriftCommentsRepository(
    this._db, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _outbox = OutboxWriter(_db, uuid: _uuid, clock: clock);

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final OutboxWriter _outbox;

  DateTime _now() => _clock().toUtc();

  @override
  Stream<List<Comment>> watchComments(String cardId) {
    final query = _db.select(_db.comments)
      ..where((c) => c.cardId.equals(cardId) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.createdAt),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch().map((rows) => rows.map(_toComment).toList());
  }

  @override
  Future<Comment> addComment({
    required String cardId,
    required String authorId,
    required String text,
    required List<String> mentions,
  }) => _db.transaction(() async {
    final now = _now();
    final row = await _db
        .into(_db.comments)
        .insertReturning(
          CommentsCompanion.insert(
            id: _uuid.v4(),
            cardId: cardId,
            authorId: authorId,
            content: text.trim(),
            mentions: Value(mentions),
            createdAt: now,
            updatedAt: now,
          ),
        );
    // The server takes the author from the session, not the payload.
    await _outbox.enqueue(SyncEntity.comment, row.id, SyncOperation.create, {
      'cardId': cardId,
      'text': row.content,
      'mentions': row.mentions,
      'createdAt': wireDate(row.createdAt),
    });
    return _toComment(row);
  });

  @override
  Future<void> editComment(
    String commentId, {
    required String text,
    required List<String> mentions,
  }) => _db.transaction(() async {
    final row = await (_db.select(
      _db.comments,
    )..where((c) => c.id.equals(commentId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final value = text.trim();
    final changes = {
      if (value != row.content) 'text': value,
      if (!listEquals(mentions, row.mentions)) 'mentions': mentions,
    };
    if (changes.isEmpty) return;
    await (_db.update(
      _db.comments,
    )..where((c) => c.id.equals(commentId))).write(
      CommentsCompanion(
        content: Value(value),
        mentions: Value(mentions),
        updatedAt: Value(_now()),
      ),
    );
    await _outbox.enqueue(
      SyncEntity.comment,
      commentId,
      SyncOperation.update,
      changes,
    );
  });

  @override
  Future<void> deleteComment(String commentId) => _db.transaction(() async {
    final now = _now();
    await (_db.update(_db.comments)..where((c) => c.id.equals(commentId)))
        .write(CommentsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    await _outbox.enqueue(
      SyncEntity.comment,
      commentId,
      SyncOperation.delete,
    );
  });

  static Comment _toComment(CommentRow row) => Comment(
    id: row.id,
    cardId: row.cardId,
    authorId: row.authorId,
    text: row.content,
    mentions: row.mentions,
    createdAt: row.createdAt,
    // Version 0 = the server has not returned this row yet.
    pending: row.version == 0,
  );
}
