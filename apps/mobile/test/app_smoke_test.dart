import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await openProfile(tester);
    await tester.tap(find.text('Language and theme'));
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
    await openProfile(tester);

    final signOut = find.byKey(const ValueKey('logout'));
    await tester.ensureVisible(signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    // A chosen sign-out is not an expired session.
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsNothing,
    );
  });
}
