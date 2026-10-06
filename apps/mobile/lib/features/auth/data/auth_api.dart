import 'package:dio/dio.dart';
import 'package:flowboard/core/network/auth_interceptor.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/features/auth/domain/user.dart';

class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as Map<String, dynamic>;
    return AuthResult(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      ),
    );
  }

  final User user;
  final AuthTokens tokens;
}

/// Thin HTTP layer over /auth and /users. Throws [DioException].
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthExtra.skipAuth: true});

  Future<AuthResult> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: _public,
    );
    return AuthResult.fromJson(res.data!);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'locale': locale,
      },
      options: _public,
    );
    return AuthResult.fromJson(res.data!);
  }

  Future<void> logout(String refreshToken) => _dio.post<void>(
    '/auth/logout',
    data: {'refreshToken': refreshToken},
    options: _public,
  );

  Future<User> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(res.data!);
  }
}
