import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BoardsState extends Equatable {
  const BoardsState({
    this.loading = true,
    this.boards = const [],
    this.workspace,
  });

  final bool loading;
  final List<Board> boards;

  /// For the title; `null` until loaded (or unavailable offline).
  final Workspace? workspace;

  BoardsState copyWith({
    bool? loading,
    List<Board>? boards,
    Workspace? workspace,
  }) => BoardsState(
    loading: loading ?? this.loading,
    boards: boards ?? this.boards,
    workspace: workspace ?? this.workspace,
  );

  @override
  List<Object?> get props => [loading, boards, workspace];
}

/// Boards of one workspace, streamed from the local DB.
class BoardsCubit extends Cubit<BoardsState> {
  BoardsCubit(this._boards, this._workspaces, this.workspaceId)
    : super(const BoardsState()) {
    _subscription = _boards
        .watchBoards(workspaceId)
        .listen(
          (boards) => emit(state.copyWith(loading: false, boards: boards)),
        );
    unawaited(_loadWorkspace());
  }

  final BoardsRepository _boards;
  final WorkspacesRepository _workspaces;
  final String workspaceId;
  late final StreamSubscription<List<Board>> _subscription;

  Future<void> _loadWorkspace() async {
    try {
      final workspace = await _workspaces.get(workspaceId);
      if (!isClosed) emit(state.copyWith(workspace: workspace));
    } on ApiException {
      // Title falls back to the generic "Boards".
    }
  }

  Future<Board> create({
    required String title,
    required BoardTemplate template,
    required List<String> columnTitles,
  }) => _boards.createBoard(
    workspaceId: workspaceId,
    title: title,
    template: template,
    columnTitles: columnTitles,
  );

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
