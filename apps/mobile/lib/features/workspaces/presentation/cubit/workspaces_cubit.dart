import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum LoadStatus { initial, loading, success, failure }

class WorkspacesState extends Equatable {
  const WorkspacesState({
    this.status = LoadStatus.initial,
    this.workspaces = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Workspace> workspaces;
  final ApiErrorCode? error;

  WorkspacesState copyWith({
    LoadStatus? status,
    List<Workspace>? workspaces,
    ApiErrorCode? error,
  }) => WorkspacesState(
    status: status ?? this.status,
    workspaces: workspaces ?? this.workspaces,
    error: error,
  );

  @override
  List<Object?> get props => [status, workspaces, error];
}

class WorkspacesCubit extends Cubit<WorkspacesState> {
  WorkspacesCubit(this._repository) : super(const WorkspacesState());

  final WorkspacesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final list = await _repository.list();
      emit(WorkspacesState(status: LoadStatus.success, workspaces: list));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.code));
    }
  }

  /// Returns the created workspace; throws [ApiException] for the caller UI.
  Future<Workspace> create(String name) async {
    final workspace = await _repository.create(name);
    final list = [...state.workspaces, workspace]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    emit(WorkspacesState(status: LoadStatus.success, workspaces: list));
    return workspace;
  }
}
