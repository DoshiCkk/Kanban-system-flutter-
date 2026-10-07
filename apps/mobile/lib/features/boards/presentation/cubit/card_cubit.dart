import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CardStatus { loading, ready, notFound }

class CardState extends Equatable {
  const CardState({
    this.status = CardStatus.loading,
    this.card,
    this.members,
  });

  final CardStatus status;
  final CardDetails? card;

  /// Workspace members for the assignee picker; `null` = unavailable
  /// (offline with an empty cache).
  final List<Member>? members;

  Member? get assignee {
    final id = card?.assigneeId;
    if (id == null) return null;
    return members?.where((m) => m.user.id == id).firstOrNull;
  }

  CardState copyWith({
    CardStatus? status,
    CardDetails? card,
    List<Member>? members,
  }) => CardState(
    status: status ?? this.status,
    card: card ?? this.card,
    members: members ?? this.members,
  );

  @override
  List<Object?> get props => [status, card, members];
}

class CardCubit extends Cubit<CardState> {
  CardCubit({
    required this.cardId,
    required this._cards,
    required this._boards,
    required this._workspaces,
  }) : super(const CardState()) {
    _subscription = _cards.watchCard(cardId).listen(_onCard);
  }

  final String cardId;
  final CardRepository _cards;
  final BoardsRepository _boards;
  final WorkspacesRepository _workspaces;
  late final StreamSubscription<CardDetails?> _subscription;
  bool _membersRequested = false;

  void _onCard(CardDetails? card) {
    if (card == null) {
      emit(const CardState(status: CardStatus.notFound));
      return;
    }
    emit(state.copyWith(status: CardStatus.ready, card: card));
    if (!_membersRequested) {
      _membersRequested = true;
      unawaited(_loadMembers(card.workspaceId));
    }
  }

  Future<void> _loadMembers(String workspaceId) async {
    try {
      final members = await _workspaces.members(workspaceId);
      if (!isClosed) emit(state.copyWith(members: members));
    } on ApiException {
      // Assignee picker shows "unavailable offline".
    }
  }

  Future<void> update(CardPatch patch) => _cards.updateCard(cardId, patch);

  Future<void> rename(String title) async {
    if (title.trim().isEmpty || title.trim() == state.card?.title) return;
    await update(CardPatch(title: title));
  }

  Future<void> addLabel(String label) async {
    final card = state.card;
    final value = label.trim();
    if (card == null || value.isEmpty || card.labels.contains(value)) return;
    await update(CardPatch(labels: [...card.labels, value]));
  }

  Future<void> removeLabel(String label) async {
    final card = state.card;
    if (card == null) return;
    await update(
      CardPatch(labels: card.labels.where((l) => l != label).toList()),
    );
  }

  /// Moves the card to the end of [columnId].
  Future<void> moveToColumn(String columnId) async {
    if (columnId == state.card?.columnId) return;
    await _boards.moveCard(
      cardId,
      toColumnId: columnId,
      // Clamped to the end by the repository.
      toIndex: 1 << 30,
    );
  }

  Future<void> moveToNextColumn() async {
    final next = state.card?.nextColumn;
    if (next != null) await moveToColumn(next.id);
  }

  Future<void> addChecklistItem(String text) async {
    if (text.trim().isEmpty) return;
    await _cards.addChecklistItem(cardId, text);
  }

  Future<void> toggleChecklistItem(ChecklistItem item) =>
      _cards.updateChecklistItem(item.id, done: !item.done);

  Future<void> deleteChecklistItem(String itemId) =>
      _cards.deleteChecklistItem(itemId);

  Future<void> delete() => _cards.deleteCard(cardId);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
