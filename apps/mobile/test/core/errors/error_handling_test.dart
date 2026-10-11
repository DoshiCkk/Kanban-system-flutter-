import 'dart:ui';

import 'package:flowboard/core/errors/error_handling.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncaught async errors are logged and handled', () {
    final previous = (
      FlutterError.onError,
      PlatformDispatcher.instance.onError,
    );
    addTearDown(() {
      FlutterError.onError = previous.$1;
      PlatformDispatcher.instance.onError = previous.$2;
    });
    final logged = <Object>[];
    installErrorHandlers(log: (error, _) => logged.add(error));

    final handled = PlatformDispatcher.instance.onError!(
      StateError('boom'),
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(logged.single, isA<StateError>());
  });

  testWidgets('the placeholder explains itself when localized', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: BrokenWidgetPlaceholder(),
      ),
    );
    expect(find.text('Не удалось показать эту часть экрана.'), findsOneWidget);
  });
}
