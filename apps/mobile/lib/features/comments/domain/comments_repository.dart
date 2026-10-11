import 'package:flowboard/features/comments/domain/comment.dart';

/// Local-first card comments, synced like every other entity.
abstract interface class CommentsRepository {
  /// Live comments of a card, oldest first.
  Stream<List<Comment>> watchComments(String cardId);

  Future<Comment> addComment({
    required String cardId,
    required String authorId,
    required String text,
    required List<String> mentions,
  });

  /// Only the author may edit; the server rejects anyone else.
  Future<void> editComment(
    String commentId, {
    required String text,
    required List<String> mentions,
  });

  Future<void> deleteComment(String commentId);
}
