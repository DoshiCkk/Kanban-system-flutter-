import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flowboard/core/network/auth_interceptor.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// Minimal fake server: `/users/me` accepts only the current valid token,
/// `/auth/refresh` rotates tokens (or fails when [refreshStatus] != 200).
class FakeServer implements HttpClientAdapter {
  String validAccess = 'access-2';
  int refreshStatus = 200;
  int refreshCalls = 0;
  final authHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    switch (options.path) {
      case '/auth/refresh':
        refreshCalls += 1;
        if (refreshStatus != 200) {
          return _json({'code': 'INVALID_REFRESH_TOKEN'}, refreshStatus);
        }
        return _json({
          'accessToken': validAccess,
          'refreshToken': 'refresh-2',
          'expiresIn': 900,
        }, 200);
      default:
        final header = options.headers['Authorization'] as String?;
        authHeaders.add(header);
        if (header == 'Bearer $validAccess') return _json({'ok': true}, 200);
        return _json({'message': 'Unauthorized'}, 401);
    }
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeServer server;
  late InMemorySessionStorage storage;
  late TokenStore tokens;
  late Dio dio;
  late int expiredCalls;

  setUp(() async {
    server = FakeServer();
    storage = InMemorySessionStorage()
      ..tokens = const AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
    tokens = TokenStore(storage);
    await tokens.load();
    expiredCalls = 0;
    final options = BaseOptions(baseUrl: 'http://test');
    dio = Dio(options)..httpClientAdapter = server;
    final refreshDio = Dio(options)..httpClientAdapter = server;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshDio: refreshDio,
        tokens: tokens,
        onSessionExpired: () => expiredCalls += 1,
      ),
    );
  });

  test('refreshes once for concurrent 401s and retries all requests', () async {
    final responses = await Future.wait([
      for (var i = 0; i < 3; i++) dio.get<Map<String, dynamic>>('/users/me'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(server.refreshCalls, 1);
    expect(tokens.current?.accessToken, 'access-2');
    expect(storage.tokens?.refreshToken, 'refresh-2');
  });

  test('clears the session when the refresh token is rejected', () async {
    server.refreshStatus = 401;

    await expectLater(
      dio.get<void>('/users/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(expiredCalls, 1);
    expect(tokens.current, isNull);
    expect(storage.tokens, isNull);
  });

  test('attaches the current token without refreshing when valid', () async {
    server.validAccess = 'access-1';
    await dio.get<void>('/users/me');
    expect(server.authHeaders.single, 'Bearer access-1');
    expect(server.refreshCalls, 0);
  });

  test('never attaches a token to skipAuth requests', () async {
    await expectLater(
      dio.get<void>(
        '/users/me',
        options: Options(extra: {AuthExtra.skipAuth: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(server.authHeaders.single, isNull);
    expect(server.refreshCalls, 0);
  });
}
