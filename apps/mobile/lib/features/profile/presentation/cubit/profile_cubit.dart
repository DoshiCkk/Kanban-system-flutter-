import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum RenameStatus { idle, saving, saved, failed }

class ProfileState extends Equatable {
  const ProfileState({
    this.workspaceCount,
    this.rename = RenameStatus.idle,
    this.error,
  });

  /// `null` until loaded (or offline with nothing cached).
  final int? workspaceCount;
  final RenameStatus rename;
  final ApiErrorCode? error;

  ProfileState copyWith({
    int? workspaceCount,
    RenameStatus? rename,
    ApiErrorCode? error,
  }) => ProfileState(
    workspaceCount: workspaceCount ?? this.workspaceCount,
    rename: rename ?? this.rename,
    error: error,
  );

  @override
  List<Object?> get props => [workspaceCount, rename, error];
}

/// Profile extras around the signed-in user (who comes from AuthCubit):
/// workspace count and renaming.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._auth, this._workspaces) : super(const ProfileState());

  final AuthRepository _auth;
  final WorkspacesRepository _workspaces;

  Future<void> load() async {
    try {
      final workspaces = await _workspaces.list();
      if (!isClosed) emit(state.copyWith(workspaceCount: workspaces.length));
    } on ApiException {
      // The stat stays hidden.
    }
  }

  /// Saves a new display name; AuthCubit picks up the updated user.
  Future<void> rename(String name) async {
    final value = name.trim();
    if (value.isEmpty || state.rename == RenameStatus.saving) return;
    emit(state.copyWith(rename: RenameStatus.saving));
    try {
      await _auth.updateName(value);
      if (!isClosed) emit(state.copyWith(rename: RenameStatus.saved));
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(rename: RenameStatus.failed, error: e.code));
      }
    }
  }
}
