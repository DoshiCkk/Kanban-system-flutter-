import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('switches language to Russian and Kazakh', (tester) async {
    final app = await pumpFlowBoard(tester);
    expect(find.text('No workspaces yet'), findsOneWidget);

    await openSettings(tester);
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);

    await tester.ensureVisible(find.text('Қазақша'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();
    expect(find.text('Баптаулар'), findsOneWidget);
    expect(app.settings.settings.language, AppLanguage.kk);
  });

  testWidgets('switches theme to dark', (tester) async {
    final app = await pumpFlowBoard(tester);
    await openSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Settings'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(app.settings.settings.themeMode, ThemeMode.dark);
  });

  testWidgets('sign out returns to the login screen', (tester) async {
    await pumpFlowBoard(tester);
    await openSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
