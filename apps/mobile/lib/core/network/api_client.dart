import 'package:dio/dio.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/network/auth_interceptor.dart';
import 'package:flowboard/core/network/session_storage.dart';

BaseOptions _baseOptions(AppConfig config) => BaseOptions(
  baseUrl: config.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  contentType: Headers.jsonContentType,
);

/// The app's Dio and its auth interceptor, whose token refresh is shared
/// with the real-time socket.
typedef ApiClient = ({Dio dio, AuthInterceptor auth});

/// Builds the app's Dio with the auth interceptor wired in.
ApiClient createApiClient({
  required AppConfig config,
  required TokenStore tokens,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(_baseOptions(config));
  // Refresh requests go through a bare client so they never recurse into
  // the interceptor.
  final refreshDio = Dio(_baseOptions(config));
  final auth = AuthInterceptor(
    dio: dio,
    refreshDio: refreshDio,
    tokens: tokens,
    onSessionExpired: onSessionExpired,
  );
  dio.interceptors.add(auth);
  return (dio: dio, auth: auth);
}
