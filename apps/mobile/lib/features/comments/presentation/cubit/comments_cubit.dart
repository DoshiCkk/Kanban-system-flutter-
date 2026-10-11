import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/features/comments/domain/comment.dart';
import 'package:flowboard/features/comments/domain/comments_repository.dart';
import 'package:flowboard/features/comments/domain/mentions.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommentsState extends Equatable {
  const CommentsState({this.comments = const [], this.editing});

  final List<Comment> comments;

  /// Own comment loaded into the composer for editing.
  final Comment? editing;

  @override
  List<Object?> get props => [comments, editing];
}

class CommentsCubit extends Cubit<CommentsState> {
  CommentsCubit({
    required this.cardId,
    required this.currentUserId,
    required this._comments,
  }) : super(const CommentsState()) {
    _subscription = _comments.watchComments(cardId).listen(_onComments);
  }

  final String cardId;
  final String currentUserId;
  final CommentsRepository _comments;
  late final StreamSubscription<List<Comment>> _subscription;

  bool isMine(Comment comment) => comment.authorId == currentUserId;

  void _onComments(List<Comment> comments) {
    final editingId = state.editing?.id;
    emit(
      CommentsState(
        comments: comments,
        // Stop editing a comment that was deleted meanwhile.
        editing: comments.where((c) => c.id == editingId).firstOrNull,
      ),
    );
  }

  /// Saves the composer text as a new comment, or as the edit in progress.
  /// [members] resolve `@Name` mentions; `null` = member list unavailable
  /// (offline, nothing cached), so an edit keeps its old mentions.
  Future<bool> submit(String text, List<MemberUser>? members) async {
    final value = text.trim();
    if (value.isEmpty) return false;
    final editing = state.editing;
    if (editing != null) {
      emit(CommentsState(comments: state.comments));
      await _comments.editComment(
        editing.id,
        text: value,
        mentions: members == null
            ? editing.mentions
            : mentionedIds(value, members),
      );
    } else {
      await _comments.addComment(
        cardId: cardId,
        authorId: currentUserId,
        text: value,
        mentions: mentionedIds(value, members ?? const []),
      );
    }
    return true;
  }

  void startEditing(Comment comment) {
    if (isMine(comment)) {
      emit(CommentsState(comments: state.comments, editing: comment));
    }
  }

  void cancelEditing() => emit(CommentsState(comments: state.comments));

  Future<void> delete(Comment comment) async {
    if (!isMine(comment)) return;
    if (state.editing?.id == comment.id) cancelEditing();
    await _comments.deleteComment(comment.id);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
