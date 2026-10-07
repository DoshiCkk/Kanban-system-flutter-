import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum BoardStatus { loading, ready, notFound }

class BoardState extends Equatable {
  const BoardState({this.status = BoardStatus.loading, this.content});

  final BoardStatus status;
  final BoardContent? content;

  List<ColumnWithCards> get columns => content?.columns ?? const [];

  @override
  List<Object?> get props => [status, content];
}

/// One board: columns with cards. All mutations go to the repository; the
/// UI updates from the DB stream (single source of truth).
class BoardCubit extends Cubit<BoardState> {
  BoardCubit(this._repository, this.boardId) : super(const BoardState()) {
    _subscription = _repository
        .watchBoard(boardId)
        .listen(
          (content) => emit(
            content == null
                ? const BoardState(status: BoardStatus.notFound)
                : BoardState(status: BoardStatus.ready, content: content),
          ),
        );
  }

  final BoardsRepository _repository;
  final String boardId;
  late final StreamSubscription<BoardContent?> _subscription;

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
