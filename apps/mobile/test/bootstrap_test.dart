import 'dart:async';

import 'package:flowboard/bootstrap.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ready = MaterialApp(home: Text('ready'));

  testWidgets('shows the splash until start-up and the minimum time pass', (
    tester,
  ) async {
    final init = Completer<void>();
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => init.future,
        builder: (_) => ready,
        settings: const AppSettings(language: AppLanguage.ru),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('FlowBoard'), findsOneWidget);
    expect(find.text('Канбан для небольших команд'), findsOneWidget);

    // Start-up is quick, but the brand stays for the minimum time.
    init.complete();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('waits for a slow start-up', (tester) async {
    final init = Completer<void>();
    await tester.pumpWidget(
      AppBootstrap(initialize: () => init.future, builder: (_) => ready),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SplashScreen), findsOneWidget);

    init.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('says so when start-up fails', (tester) async {
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () async => throw StateError('no database'),
        builder: (_) => ready,
        minimumSplash: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    // Reported to the error log as well.
    expect(tester.takeException(), isA<StateError>());
    expect(
      find.text('Could not start the app. Please restart it.'),
      findsOneWidget,
    );
    expect(find.text('ready'), findsNothing);
  });
}
