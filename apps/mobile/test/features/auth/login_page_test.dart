import 'package:flowboard/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('validates fields before submitting', (tester) async {
    final app = await pumpFlowBoard(tester, signedIn: false);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(app.authCubit.state.isAuthenticated, isFalse);
  });

  testWidgets('shows a localized server error', (tester) async {
    final app = await pumpFlowBoard(tester, signedIn: false);
    app.auth.failWith = ApiErrorCode.invalidCredentials;

    await tester.enterText(field('Email'), 'aigerim@example.com');
    await tester.enterText(field('Password'), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password'), findsOneWidget);
  });

  testWidgets('successful login opens workspaces', (tester) async {
    await pumpFlowBoard(tester, signedIn: false);

    await tester.enterText(field('Email'), 'aigerim@example.com');
    await tester.enterText(field('Password'), 'correct-horse');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Workspaces'), findsOneWidget);
  });

  testWidgets('registration enforces the minimum password length', (
    tester,
  ) async {
    await pumpFlowBoard(tester, signedIn: false);
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Your name'), 'Aigerim');
    await tester.enterText(field('Email'), 'aigerim@example.com');
    await tester.enterText(field('Password'), 'short');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });
}
