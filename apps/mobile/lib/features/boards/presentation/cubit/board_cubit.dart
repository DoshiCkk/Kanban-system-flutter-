import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/features/boards/domain/board_filter.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum BoardStatus { loading, ready, notFound }

class BoardState extends Equatable {
  const BoardState({
    this.status = BoardStatus.loading,
    this.content,
    this.filter = const BoardFilter(),
    this.userId = '',
  });

  final BoardStatus status;
  final BoardContent? content;
  final BoardFilter filter;

  /// For the "assigned to me" filter.
  final String userId;

  /// All columns with all their cards.
  List<ColumnWithCards> get columns => content?.columns ?? const [];

  /// The same columns with only the cards that pass [filter].
  List<ColumnWithCards> get visibleColumns {
    if (!filter.isActive) return columns;
    final now = DateTime.now();
    return [
      for (final column in columns)
        column.copyWith(
          cards: [
            for (final card in column.cards)
              if (filter.matches(card, userId: userId, now: now)) card,
          ],
        ),
    ];
  }

  int get cardCount => columns.fold(0, (n, c) => n + c.cards.length);

  /// Labels used on this board, for the filter sheet.
  List<String> get labels => {
    for (final column in columns)
      for (final card in column.cards) ...card.labels,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  BoardState copyWith({
    BoardStatus? status,
    BoardContent? content,
    BoardFilter? filter,
  }) => BoardState(
    status: status ?? this.status,
    content: content ?? this.content,
    filter: filter ?? this.filter,
    userId: userId,
  );

  @override
  List<Object?> get props => [status, content, filter, userId];
}

/// One board: columns with cards. All mutations go to the repository; the
/// UI updates from the DB stream (single source of truth).
class BoardCubit extends Cubit<BoardState> {
  BoardCubit(this._repository, this.boardId, {String currentUserId = ''})
    : super(BoardState(userId: currentUserId)) {
    _subscription = _repository
        .watchBoard(boardId)
        .listen(
          (content) => emit(
            content == null
                ? BoardState(status: BoardStatus.notFound, userId: state.userId)
                : state.copyWith(status: BoardStatus.ready, content: content),
          ),
        );
  }

  final BoardsRepository _repository;
  final String boardId;
  late final StreamSubscription<BoardContent?> _subscription;

  void search(String query) =>
      emit(state.copyWith(filter: state.filter.copyWith(query: query)));

  void setFilter(BoardFilter filter) => emit(state.copyWith(filter: filter));

  /// Clears the filters but keeps the search query.
  void clearFilters() =>
      emit(state.copyWith(filter: BoardFilter(query: state.filter.query)));

  Future<void> createCard(String columnId, String title) async {
    if (title.trim().isEmpty) return;
    await _repository.createCard(columnId, title);
  }

  Future<void> moveCard(String cardId, String toColumnId, int toIndex) =>
      _repository.moveCard(cardId, toColumnId: toColumnId, toIndex: toIndex);

  Future<void> addColumn(String title) async {
    if (title.trim().isEmpty) return;
    await _repository.addColumn(boardId, title);
  }

  Future<void> renameColumn(String columnId, String title) async {
    if (title.trim().isEmpty) return;
    await _repository.renameColumn(columnId, title);
  }

  Future<void> deleteColumn(String columnId) =>
      _repository.deleteColumn(columnId);

  Future<void> renameBoard(String title) async {
    if (title.trim().isEmpty) return;
    await _repository.renameBoard(boardId, title);
  }

  Future<void> deleteBoard() => _repository.deleteBoard(boardId);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
