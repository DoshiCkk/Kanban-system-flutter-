import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyTasksState extends Equatable {
  const MyTasksState({this.loading = true, this.groups = const {}});

  final bool loading;
  final Map<TaskGroup, List<AssignedCard>> groups;

  int count(TaskGroup group) => groups[group]?.length ?? 0;

  /// Assigned and not done.
  int get active => groups.entries
      .where((e) => e.key != TaskGroup.done)
      .fold(0, (sum, e) => sum + e.value.length);

  bool get isEmpty => groups.isEmpty;

  @override
  List<Object?> get props => [loading, groups];
}

/// Cards assigned to the signed-in user across all local boards. Shared by
/// the home summary, the "My tasks" tab (and its badge) and the profile.
class MyTasksCubit extends Cubit<MyTasksState> {
  MyTasksCubit(
    this._repository, {
    required this.userId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const MyTasksState()) {
    _subscription = _repository
        .watchAssignedCards(userId)
        .listen(
          (tasks) => emit(
            MyTasksState(loading: false, groups: groupTasks(tasks, _clock())),
          ),
        );
  }

  final BoardsRepository _repository;
  final String userId;
  final DateTime Function() _clock;
  late final StreamSubscription<List<AssignedCard>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
