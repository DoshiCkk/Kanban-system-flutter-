import 'package:flowboard/features/auth/domain/user.dart';

/// Owns the session. Emits on [userChanges] whenever the signed-in user
/// changes: login, registration, logout or server-side session expiry.
abstract interface class AuthRepository {
  User? get currentUser;

  Stream<User?> get userChanges;

  /// Restores the session from secure storage. Works offline.
  Future<User?> restore();

  Future<User> login({required String email, required String password});

  /// Creates the account without signing in: the user signs in next with
  /// the new credentials.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  });

  /// Renames the signed-in user (needs the network).
  Future<User> updateName(String name);

  /// Re-fetches the profile; keeps the cached one when offline.
  Future<User?> refreshProfile();

  /// Revokes the refresh token server-side (best effort) and clears local data.
  Future<void> logout();
}
