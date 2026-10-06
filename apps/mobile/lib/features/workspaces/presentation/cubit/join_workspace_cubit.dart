import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum JoinStatus { loading, ready, joining, joined, failure }

class JoinWorkspaceState extends Equatable {
  const JoinWorkspaceState({
    this.status = JoinStatus.loading,
    this.preview,
    this.joined,
    this.error,
  });

  final JoinStatus status;
  final InvitePreview? preview;
  final Workspace? joined;
  final ApiErrorCode? error;

  @override
  List<Object?> get props => [status, preview, joined, error];
}

class JoinWorkspaceCubit extends Cubit<JoinWorkspaceState> {
  JoinWorkspaceCubit(this._repository, this.token)
    : super(const JoinWorkspaceState());

  final WorkspacesRepository _repository;
  final String token;

  Future<void> load() async {
    emit(const JoinWorkspaceState());
    try {
      final preview = await _repository.previewInvite(token);
      emit(JoinWorkspaceState(status: JoinStatus.ready, preview: preview));
    } on ApiException catch (e) {
      emit(JoinWorkspaceState(status: JoinStatus.failure, error: e.code));
    }
  }

  Future<void> accept() async {
    final preview = state.preview;
    if (state.status != JoinStatus.ready || preview == null) return;
    emit(JoinWorkspaceState(status: JoinStatus.joining, preview: preview));
    try {
      final workspace = await _repository.acceptInvite(token);
      emit(
        JoinWorkspaceState(
          status: JoinStatus.joined,
          preview: preview,
          joined: workspace,
        ),
      );
    } on ApiException catch (e) {
      emit(
        JoinWorkspaceState(
          status: JoinStatus.ready,
          preview: preview,
          error: e.code,
        ),
      );
    }
  }
}
