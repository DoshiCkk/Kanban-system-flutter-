import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];
}

/// Persists the session (tokens + cached profile JSON) across restarts.
abstract interface class SessionStorage {
  Future<AuthTokens?> readTokens();

  Future<void> writeTokens(AuthTokens tokens);

  Future<String?> readUserJson();

  Future<void> writeUserJson(String json);

  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable after first unlock so background sync can use tokens.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';
  static const _userKey = 'auth.user';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> readTokens() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<void> writeUserJson(String json) =>
      _storage.write(key: _userKey, value: json);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}

/// In-memory view of the current tokens, shared by the auth interceptor and
/// the auth repository. Writes go through to [SessionStorage].
class TokenStore {
  TokenStore(this._storage);

  final SessionStorage _storage;
  AuthTokens? _current;

  AuthTokens? get current => _current;

  Future<AuthTokens?> load() async => _current = await _storage.readTokens();

  Future<void> save(AuthTokens tokens) async {
    _current = tokens;
    await _storage.writeTokens(tokens);
  }

  Future<void> clear() async {
    _current = null;
    await _storage.clear();
  }
}
