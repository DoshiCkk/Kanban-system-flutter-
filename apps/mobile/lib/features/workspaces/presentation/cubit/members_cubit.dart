import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MembersState extends Equatable {
  const MembersState({
    this.status = LoadStatus.initial,
    this.workspace,
    this.members = const [],
    this.error,
  });

  final LoadStatus status;
  final Workspace? workspace;
  final List<Member> members;
  final ApiErrorCode? error;

  @override
  List<Object?> get props => [status, workspace, members, error];
}

/// Members screen. Mutations throw [ApiException] so the UI can show a
/// snackbar; the list stays as it was.
class MembersCubit extends Cubit<MembersState> {
  MembersCubit(this._repository, this.workspaceId)
    : super(const MembersState());

  final WorkspacesRepository _repository;
  final String workspaceId;

  Future<void> load() async {
    emit(
      MembersState(
        status: LoadStatus.loading,
        workspace: state.workspace,
        members: state.members,
      ),
    );
    try {
      // Future.wait rethrows the first error unwrapped.
      final results = await Future.wait<Object>([
        _repository.get(workspaceId),
        _repository.members(workspaceId),
      ]);
      emit(
        MembersState(
          status: LoadStatus.success,
          workspace: results[0] as Workspace,
          members: results[1] as List<Member>,
        ),
      );
    } on ApiException catch (e) {
      emit(
        MembersState(
          status: LoadStatus.failure,
          workspace: state.workspace,
          members: state.members,
          error: e.code,
        ),
      );
    }
  }

  Future<Invite> createInvite() => _repository.createInvite(workspaceId);

  Future<void> changeRole(String userId, WorkspaceRole role) async {
    final updated = await _repository.updateRole(workspaceId, userId, role);
    emit(
      MembersState(
        status: state.status,
        workspace: state.workspace,
        members: [
          for (final m in state.members)
            if (m.user.id == userId) updated else m,
        ],
      ),
    );
  }

  Future<void> remove(String userId) async {
    await _repository.removeMember(workspaceId, userId);
    emit(
      MembersState(
        status: state.status,
        workspace: state.workspace,
        members: state.members.where((m) => m.user.id != userId).toList(),
      ),
    );
  }
}
