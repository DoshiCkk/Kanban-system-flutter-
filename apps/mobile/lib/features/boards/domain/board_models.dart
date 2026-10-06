import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_models.freezed.dart';

enum CardPriority { low, medium, high }

/// Board templates offered on creation. Column titles are localized by the
/// UI at creation time and stored as plain data.
enum BoardTemplate {
  basic(columnCount: 3),
  development(columnCount: 5),
  empty(columnCount: 0);

  const BoardTemplate({required this.columnCount});

  final int columnCount;
}

@freezed
abstract class Board with _$Board {
  const factory Board({
    required String id,
    required String workspaceId,
    required String title,
    required DateTime updatedAt,
    String? templateKey,
  }) = _Board;
}

@freezed
abstract class BoardColumn with _$BoardColumn {
  const factory BoardColumn({
    required String id,
    required String boardId,
    required String title,
    required String position,
    int? wipLimit,
  }) = _BoardColumn;
}

@freezed
abstract class CardSummary with _$CardSummary {
  const factory CardSummary({
    required String id,
    required String columnId,
    required String title,
    required CardPriority priority,
    required String position,
    @Default(<String>[]) List<String> labels,
    DateTime? dueDate,
    String? assigneeId,
    @Default(0) int checklistDone,
    @Default(0) int checklistTotal,
  }) = _CardSummary;
}

@freezed
abstract class ColumnWithCards with _$ColumnWithCards {
  const factory ColumnWithCards({
    required BoardColumn column,
    required List<CardSummary> cards,
  }) = _ColumnWithCards;
}

@freezed
abstract class BoardContent with _$BoardContent {
  const factory BoardContent({
    required Board board,
    required List<ColumnWithCards> columns,
  }) = _BoardContent;
}

@freezed
abstract class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String id,
    required String text,
    required bool done,
    required String position,
  }) = _ChecklistItem;
}

@freezed
abstract class CardDetails with _$CardDetails {
  const factory CardDetails({
    required String id,
    required String boardId,
    required String workspaceId,
    required String columnId,
    required String title,
    required String description,
    required CardPriority priority,
    required List<String> labels,
    required List<ChecklistItem> checklist,

    /// All live columns of the board in order (for status and "next").
    required List<BoardColumn> columns,
    DateTime? dueDate,
    String? assigneeId,
  }) = _CardDetails;

  const CardDetails._();

  BoardColumn? get column => columns.where((c) => c.id == columnId).firstOrNull;

  BoardColumn? get nextColumn {
    final index = columns.indexWhere((c) => c.id == columnId);
    return index >= 0 && index + 1 < columns.length ? columns[index + 1] : null;
  }
}

/// Partial update of a card. `null` = unchanged; use the `clear*` flags to
/// set nullable fields to null.
class CardPatch {
  const CardPatch({
    this.title,
    this.description,
    this.priority,
    this.labels,
    this.dueDate,
    this.clearDueDate = false,
    this.assigneeId,
    this.clearAssignee = false,
  });

  final String? title;
  final String? description;
  final CardPriority? priority;
  final List<String>? labels;
  final DateTime? dueDate;
  final bool clearDueDate;
  final String? assigneeId;
  final bool clearAssignee;
}
