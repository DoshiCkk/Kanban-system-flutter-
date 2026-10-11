import 'dart:convert';

import 'package:flowboard/core/network/session_storage.dart';

/// Returns a usable access token, refreshing it first when [refresh] is set
/// or the current one is about to expire. `null` = signed out or the
/// refresh failed.
typedef AccessTokenGetter = Future<String?> Function({bool refresh});

/// Access tokens for clients outside Dio (the Socket.IO handshake), which
/// cannot rely on the auth interceptor's refresh-on-401.
class AccessTokenSource {
  AccessTokenSource(
    this._tokens,
    this._refresh, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Refresh this long before expiry to absorb clock skew and latency.
  static const leeway = Duration(minutes: 1);

  final TokenStore _tokens;
  final Future<String?> Function() _refresh;
  final DateTime Function() _clock;

  Future<String?> call({bool refresh = false}) async {
    final token = _tokens.current?.accessToken;
    if (token == null) return null;
    final expiry = jwtExpiry(token);
    final fresh = expiry == null || expiry.isAfter(_clock().add(leeway));
    if (!refresh && fresh) return token;
    return _refresh();
  }
}

/// `exp` claim of a JWT, or `null` when it cannot be read. The signature is
/// not checked: the server does that.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map<String, dynamic> ? payload['exp'] : null;
    return exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
        : null;
  } on FormatException {
    return null;
  }
}
