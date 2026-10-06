import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/domain/user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthState extends Equatable {
  const AuthState({this.user, this.sessionExpired = false});

  final User? user;

  /// True when the server ended the session (not a user-initiated logout).
  final bool sessionExpired;

  bool get isAuthenticated => user != null;

  @override
  List<Object?> get props => [user, sessionExpired];
}

/// App-wide session state. The router redirects based on it.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository)
    : super(AuthState(user: _repository.currentUser)) {
    _subscription = _repository.userChanges.listen(_onUser);
  }

  final AuthRepository _repository;
  late final StreamSubscription<User?> _subscription;
  bool _loggingOut = false;

  void _onUser(User? user) {
    final expired = user == null && state.isAuthenticated && !_loggingOut;
    emit(AuthState(user: user, sessionExpired: expired));
  }

  /// Refreshes the cached profile in the background; ignores failures.
  Future<void> refreshProfile() async {
    try {
      await _repository.refreshProfile();
    } on Exception {
      // Session expiry is reported through userChanges.
    }
  }

  Future<void> logout() async {
    _loggingOut = true;
    try {
      await _repository.logout();
    } finally {
      _loggingOut = false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
