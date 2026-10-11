import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flowboard/core/notifications/push_notification_service.dart';
import 'package:flutter/foundation.dart';

/// [PushPlatform] over Firebase Cloud Messaging. Reads the native Firebase
/// config (google-services.json / GoogleService-Info.plist, docs/push.md).
class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform._(this._messaging);

  final FirebaseMessaging _messaging;

  /// `null` when Firebase is not configured for this build: the app then
  /// runs without push instead of failing.
  static Future<FirebasePushPlatform?> initialize() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      // Foreground pushes show as an in-app banner on both platforms.
      await messaging.setForegroundNotificationPresentationOptions(
        badge: true,
        sound: true,
      );
      return FirebasePushPlatform._(messaging);
    } on Object catch (e) {
      debugPrint('push: Firebase is not configured: $e');
      return null;
    }
  }

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      _ => false,
    };
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<RemotePush> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPush);

  @override
  Stream<RemotePush> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPush);

  @override
  Future<RemotePush?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPush(message);
  }

  static RemotePush _toPush(RemoteMessage message) => RemotePush(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );
}
