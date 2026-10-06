import 'package:flowboard/app.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_settings_repository.dart';

void main() {
  late InMemorySettingsRepository repository;

  setUp(
    () => repository = InMemorySettingsRepository(
      const AppSettings(language: AppLanguage.en),
    ),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      FlowBoardApp(settingsRepository: repository, router: createRouter()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('switches language to Russian and Kazakh', (tester) async {
    await pumpApp(tester);
    expect(find.text('No boards yet'), findsOneWidget);

    await openSettings(tester);
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);

    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();
    expect(find.text('Баптаулар'), findsOneWidget);
    expect(repository.settings.language, AppLanguage.kk);
  });

  testWidgets('switches theme to dark', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Settings'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(repository.settings.themeMode, ThemeMode.dark);
  });
}
