import 'dart:async';
import 'dart:convert';

import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/features/auth/data/auth_api.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/domain/user.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._api,
    required this._tokens,
    required this._storage,
  });

  final AuthApi _api;
  final TokenStore _tokens;
  final SessionStorage _storage;
  final _controller = StreamController<User?>.broadcast();

  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get userChanges => _controller.stream;

  @override
  Future<User?> restore() async {
    final tokens = await _tokens.load();
    final json = await _storage.readUserJson();
    if (tokens == null || json == null) {
      await _tokens.clear();
      return _user = null;
    }
    try {
      return _user = User.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on FormatException {
      await _tokens.clear();
      return _user = null;
    }
  }

  @override
  Future<User> login({required String email, required String password}) =>
      guardApi(() async => _start(await _api.login(email, password)));

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  }) => guardApi(
    () async => _start(
      await _api.register(
        name: name,
        email: email,
        password: password,
        locale: locale,
      ),
    ),
  );

  @override
  Future<User?> refreshProfile() async {
    if (_tokens.current == null) return _user;
    try {
      final user = await guardApi(_api.me);
      await _setUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network) return _user;
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final refresh = _tokens.current?.refreshToken;
    if (refresh != null) {
      try {
        await guardApi(() => _api.logout(refresh));
      } on ApiException {
        // Offline logout still clears the device; the server-side token
        // simply expires.
      }
    }
    await onSessionExpired();
  }

  /// Called by the auth interceptor when the refresh token is rejected.
  Future<void> onSessionExpired() async {
    await _tokens.clear();
    _user = null;
    _controller.add(null);
  }

  Future<User> _start(AuthResult result) async {
    await _tokens.save(result.tokens);
    await _setUser(result.user);
    return result.user;
  }

  Future<void> _setUser(User user) async {
    _user = user;
    await _storage.writeUserJson(jsonEncode(user.toJson()));
    _controller.add(user);
  }
}
