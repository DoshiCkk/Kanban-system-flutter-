import 'dart:convert';

import 'package:flowboard/core/network/access_token.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

String jwt(DateTime expiry) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': 'u1', 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);

  test('reads the exp claim of a JWT', () {
    expect(jwtExpiry(jwt(now)), now);
    expect(jwtExpiry('opaque'), isNull);
    expect(jwtExpiry('a.%%%.c'), isNull);
  });

  group('AccessTokenSource', () {
    late TokenStore tokens;
    late int refreshes;
    late AccessTokenSource source;

    Future<void> signIn(String access) =>
        tokens.save(AuthTokens(accessToken: access, refreshToken: 'r'));

    setUp(() {
      tokens = TokenStore(InMemorySessionStorage());
      refreshes = 0;
      source = AccessTokenSource(tokens, () async {
        refreshes++;
        return 'refreshed';
      }, clock: () => now);
    });

    test('returns null when signed out', () async {
      expect(await source(), isNull);
      expect(refreshes, 0);
    });

    test('hands out a fresh token as is', () async {
      final fresh = jwt(now.add(const Duration(minutes: 10)));
      await signIn(fresh);
      expect(await source(), fresh);
      expect(refreshes, 0);
    });

    test('refreshes a token about to expire, or when asked', () async {
      await signIn(jwt(now.add(const Duration(seconds: 30))));
      expect(await source(), 'refreshed');

      await signIn(jwt(now.add(const Duration(minutes: 10))));
      expect(await source(refresh: true), 'refreshed');
      expect(refreshes, 2);
    });
  });
}
