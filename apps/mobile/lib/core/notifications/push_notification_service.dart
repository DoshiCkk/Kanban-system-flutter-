import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';

/// A push as the platform delivers it.
class RemotePush {
  const RemotePush({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// The push SDK (Firebase Messaging in the app, a fake in tests).
abstract interface class PushPlatform {
  /// `android` or `ios`, as the API expects.
  String get platform;

  /// Asks the user (Android 13+, iOS). Returns whether pushes may show.
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> deleteToken();

  Stream<RemotePush> get onForegroundMessage;

  Stream<RemotePush> get onMessageOpenedApp;

  /// The push that launched the app, if any.
  Future<RemotePush?> getInitialMessage();
}

/// `PUT/DELETE /devices` of the API.
abstract interface class DeviceRegistry {
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  });

  Future<void> unregister(String token);
}

class DioDeviceRegistry implements DeviceRegistry {
  DioDeviceRegistry(this._dio);

  final Dio _dio;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) => guardApi(
    () => _dio.put<void>(
      '/devices',
      data: {'token': token, 'platform': platform, 'locale': locale},
    ),
  );

  @override
  Future<void> unregister(String token) => guardApi(
    () => _dio.delete<void>('/devices/${Uri.encodeComponent(token)}'),
  );
}

/// [NotificationService] over a [PushPlatform]: keeps this device's token
/// registered for the signed-in user in the current UI language.
class PushNotificationService implements NotificationService {
  PushNotificationService({required this._platform, required this._registry});

  static const _supportedLocales = {'en', 'ru', 'kk'};

  final PushPlatform _platform;
  final DeviceRegistry _registry;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _foreground = StreamController<ForegroundPush>.broadcast();
  late final _opened = StreamController<PushTarget>.broadcast(
    onListen: _flushPendingOpen,
  );

  PushTarget? _pendingOpen;
  String _locale = 'en';
  String? _token;
  bool _started = false;
  bool _registered = false;

  @override
  Stream<PushTarget> get opened => _opened.stream;

  @override
  Stream<ForegroundPush> get foreground => _foreground.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscriptions
      ..add(_platform.onMessageOpenedApp.listen(_onOpened))
      ..add(_platform.onForegroundMessage.listen(_onForeground));
    final initial = await _platform.getInitialMessage();
    if (initial != null) _onOpened(initial);

    if (!await _platform.requestPermission() || !_started) return;
    _subscriptions.add(
      _platform.onTokenRefresh.listen((token) {
        _token = token;
        unawaited(_register());
      }),
    );
    try {
      _token = await _platform.getToken();
    } on Object catch (e) {
      // iOS has no token until APNs answers; onTokenRefresh brings it.
      debugPrint('push: no token yet: $e');
    }
    await _register();
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    final token = _token;
    _token = null;
    _registered = false;
    if (token == null) return;
    try {
      await _registry.unregister(token);
    } on ApiException catch (e) {
      debugPrint('push: unregister failed: ${e.code}');
    }
    try {
      // A new token next time, even if the server kept the old one.
      await _platform.deleteToken();
    } on Object catch (e) {
      debugPrint('push: deleteToken failed: $e');
    }
  }

  @override
  void setLocale(String languageCode) {
    final locale = _supportedLocales.contains(languageCode)
        ? languageCode
        : 'en';
    if (locale == _locale) return;
    _locale = locale;
    _registered = false;
    unawaited(_register());
  }

  @override
  Future<void> retryRegistration() async {
    if (!_registered) await _register();
  }

  Future<void> _register() async {
    final token = _token;
    if (!_started || token == null) return;
    try {
      await _registry.register(
        token: token,
        platform: _platform.platform,
        locale: _locale,
      );
      _registered = token == _token;
    } on ApiException catch (e) {
      _registered = false;
      debugPrint('push: register failed: ${e.code}');
    }
  }

  void _onOpened(RemotePush push) {
    final target = PushTarget.fromData(push.data);
    if (target == null) return;
    if (_opened.hasListener) {
      _opened.add(target);
    } else {
      _pendingOpen = target;
    }
  }

  void _flushPendingOpen() {
    final target = _pendingOpen;
    _pendingOpen = null;
    if (target != null) _opened.add(target);
  }

  void _onForeground(RemotePush push) {
    final title = push.title;
    if (title == null) return;
    _foreground.add(
      ForegroundPush(
        title: title,
        body: push.body ?? '',
        target: PushTarget.fromData(push.data),
      ),
    );
  }
}
