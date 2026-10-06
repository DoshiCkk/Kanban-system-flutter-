import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('auth redirect', () {
    testWidgets('signed-out user lands on login', (tester) async {
      final app = await pumpFlowBoard(tester, signedIn: false);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(app.router.state.matchedLocation, '/login');
    });

    testWidgets('invite deep link survives the login detour', (tester) async {
      final app = await pumpFlowBoard(
        tester,
        signedIn: false,
        initialLocation: '/invite/abcdefghijklmnopqrstuvwxyz',
      );
      expect(
        app.router.state.uri.queryParameters['from'],
        startsWith('/invite/'),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'aigerim@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret-password',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        app.router.state.matchedLocation,
        '/invite/abcdefghijklmnopqrstuvwxyz',
      );
      expect(find.text('Invited team'), findsOneWidget);

      await tester.tap(find.text('Join workspace').last);
      await tester.pumpAndSettle();
      expect(app.router.state.matchedLocation, '/');
      expect(find.text('Invited team'), findsOneWidget);
    });

    testWidgets('session expiry sends the user to login with a notice', (
      tester,
    ) async {
      final app = await pumpFlowBoard(tester);
      app.auth.expireSession();
      await tester.pumpAndSettle();

      expect(app.router.state.matchedLocation, '/login');
      expect(
        find.text('Your session has expired. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('ignores protocol-relative redirect targets', (tester) async {
      final app = await pumpFlowBoard(
        tester,
        signedIn: false,
        initialLocation: '/login?from=//evil.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'aigerim@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret-password',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(app.router.state.matchedLocation, '/');
    });
  });
}
