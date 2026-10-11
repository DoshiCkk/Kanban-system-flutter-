import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowboard/core/network/session_storage.dart';

/// Request option `extra` keys.
abstract final class AuthExtra {
  /// Do not attach a token and never try to refresh (auth endpoints).
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';
}

/// Attaches the access token and transparently refreshes it on 401.
///
/// Concurrent 401s share a single refresh call ("single flight"). If the
/// refresh token is rejected, the session is cleared and `onSessionExpired`
/// fires; network failures during refresh keep the session intact.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._refreshDio,
    required this._tokens,
    required this._onSessionExpired,
  });

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStore _tokens;
  final void Function() _onSessionExpired;

  Future<String?>? _inflightRefresh;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = _tokens.current?.accessToken;
    if (options.extra[AuthExtra.skipAuth] != true && access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final eligible =
        err.response?.statusCode == 401 &&
        options.extra[AuthExtra.skipAuth] != true &&
        options.extra[AuthExtra._retried] != true &&
        _tokens.current != null;
    if (!eligible) return handler.next(err);

    // Another request may already have refreshed while this one was in flight.
    final usedHeader = options.headers['Authorization'];
    final current = _tokens.current?.accessToken;
    final String? access;
    if (current != null && usedHeader != 'Bearer $current') {
      access = current;
    } else {
      access = await refreshAccessToken();
    }
    if (access == null) return handler.next(err);

    options
      ..headers['Authorization'] = 'Bearer $access'
      ..extra[AuthExtra._retried] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Refreshes the session once for all concurrent callers (also used by
  /// the real-time socket). Returns the new access token, or `null`.
  Future<String?> refreshAccessToken() =>
      _inflightRefresh ??= _refresh().whenComplete(
        () => _inflightRefresh = null,
      );

  Future<String?> _refresh() async {
    final refreshToken = _tokens.current?.refreshToken;
    if (refreshToken == null) return null;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data!;
      final tokens = AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      await _tokens.save(tokens);
      return tokens.accessToken;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 400) {
        await _tokens.clear();
        _onSessionExpired();
      }
      return null;
    }
  }
}
