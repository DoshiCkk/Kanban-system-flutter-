import 'package:flowboard/features/boards/domain/board_models.dart';

/// Local-first board storage. All reads are streams from the local DB; all
/// writes hit the local DB first (sync is added on top in phase 4).
abstract interface class BoardsRepository {
  Stream<List<Board>> watchBoards(String workspaceId);

  /// Creates a board with one column per entry of [columnTitles].
  Future<Board> createBoard({
    required String workspaceId,
    required String title,
    required BoardTemplate template,
    required List<String> columnTitles,
  });

  Future<void> renameBoard(String boardId, String title);

  Future<void> deleteBoard(String boardId);

  /// Board with ordered columns and cards; emits `null` once deleted.
  Stream<BoardContent?> watchBoard(String boardId);

  Future<BoardColumn> addColumn(String boardId, String title);

  Future<void> renameColumn(String columnId, String title);

  /// Soft-deletes the column and its cards.
  Future<void> deleteColumn(String columnId);

  /// Appends a card to the end of [columnId].
  Future<CardSummary> createCard(String columnId, String title);

  /// Moves a card to [toIndex] among the other cards of [toColumnId].
  /// Rewrites only the moved card unless keys collide (then rebalances).
  Future<void> moveCard(
    String cardId, {
    required String toColumnId,
    required int toIndex,
  });
}

abstract interface class CardRepository {
  /// Emits `null` once the card is deleted.
  Stream<CardDetails?> watchCard(String cardId);

  Future<void> updateCard(String cardId, CardPatch patch);

  Future<void> deleteCard(String cardId);

  Future<ChecklistItem> addChecklistItem(String cardId, String text);

  Future<void> updateChecklistItem(String itemId, {String? text, bool? done});

  Future<void> deleteChecklistItem(String itemId);
}
