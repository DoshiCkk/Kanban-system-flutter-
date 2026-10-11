import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String cardId,
    required String authorId,

    /// Plain text; mentions stay readable as `@Name` (see mentions.dart).
    required String text,

    /// Ids of the workspace members the text mentions.
    required List<String> mentions,
    required DateTime createdAt,

    /// Written on this device and not acknowledged by the server yet.
    @Default(false) bool pending,
  }) = _Comment;
}
