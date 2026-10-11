import 'dart:async';

import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/notifications/notification_service.dart';
import 'package:flowboard/core/notifications/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePushPlatform implements PushPlatform {
  bool permission = true;
  String? token = 'token-1';
  RemotePush? initial;
  int deletes = 0;
  final refresh = StreamController<String>.broadcast();
  final foregroundMessages = StreamController<RemotePush>.broadcast();
  final openedMessages = StreamController<RemotePush>.broadcast();

  @override
  String get platform => 'android';

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() async => deletes++;

  @override
  Stream<RemotePush> get onForegroundMessage => foregroundMessages.stream;

  @override
  Stream<RemotePush> get onMessageOpenedApp => openedMessages.stream;

  @override
  Future<RemotePush?> getInitialMessage() async => initial;
}

class FakeRegistry implements DeviceRegistry {
  final devices = <String, String>{};
  final calls = <String>[];
  bool offline = false;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    calls.add('register $token $platform $locale');
    if (offline) throw const ApiException(ApiErrorCode.network);
    devices[token] = locale;
  }

  @override
  Future<void> unregister(String token) async {
    calls.add('unregister $token');
    devices.remove(token);
  }
}

const cardData = {
  'type': 'assigned',
  'workspaceId': 'w1',
  'boardId': 'b1',
  'cardId': 'c1',
};
const target = PushTarget(workspaceId: 'w1', boardId: 'b1', cardId: 'c1');

void main() {
  late FakePushPlatform platform;
  late FakeRegistry registry;
  late PushNotificationService service;

  setUp(() {
    platform = FakePushPlatform();
    registry = FakeRegistry();
    service = PushNotificationService(platform: platform, registry: registry);
  });

  test('registers the token in the UI language and follows changes', () async {
    service.setLocale('ru');
    await service.start();
    expect(registry.devices, {'token-1': 'ru'});

    service
      ..setLocale('ru')
      ..setLocale('kk');
    await pumpEventQueue();
    expect(registry.devices, {'token-1': 'kk'});
    // Unsupported languages fall back to English.
    service.setLocale('de');
    await pumpEventQueue();
    expect(registry.devices, {'token-1': 'en'});
    expect(registry.calls, hasLength(3));

    platform.refresh.add('token-2');
    await pumpEventQueue();
    expect(registry.devices['token-2'], 'en');
  });

  test('stays unregistered without permission', () async {
    platform.permission = false;
    await service.start();
    expect(registry.calls, isEmpty);
  });

  test('retries a registration that failed offline', () async {
    registry.offline = true;
    await service.start();
    expect(registry.devices, isEmpty);

    registry.offline = false;
    await service.retryRegistration();
    expect(registry.devices, {'token-1': 'en'});
    await service.retryRegistration();
    expect(registry.calls, hasLength(2));
  });

  test('unregisters and drops the token on sign-out', () async {
    await service.start();
    await service.stop();
    expect(registry.devices, isEmpty);
    expect(platform.deletes, 1);

    await service.stop();
    service.setLocale('kk');
    await pumpEventQueue();
    expect(registry.calls, [
      'register token-1 android en',
      'unregister token-1',
    ]);
  });

  test('keeps the push that launched the app for the first listener', () async {
    platform.initial = const RemotePush(title: 'Hi', data: cardData);
    await service.start();
    expect(await service.opened.first, target);

    final opened = service.opened.first;
    platform.openedMessages.add(const RemotePush(data: cardData));
    expect(await opened, target);
  });

  test('passes foreground pushes on with their target', () async {
    await service.start();
    final received = service.foreground.take(2).toList();
    platform.foregroundMessages
      ..add(
        const RemotePush(title: 'Due tomorrow', body: 'Intro', data: cardData),
      )
      ..add(const RemotePush(data: cardData))
      ..add(const RemotePush(title: 'No card'));
    expect(await received, const [
      ForegroundPush(title: 'Due tomorrow', body: 'Intro', target: target),
      ForegroundPush(title: 'No card', body: ''),
    ]);
  });
}
