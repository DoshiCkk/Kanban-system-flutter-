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

  Future<void> register(
    WidgetTester tester, {
    String password = 'correct-horse',
    String repeat = 'correct-horse',
  }) async {
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Your name'), 'Aigerim');
    await tester.enterText(field('Email'), ' aigerim@example.com ');
    await tester.enterText(field('Password'), password);
    await tester.enterText(field('Repeat password'), repeat);
    final submit = find.text('Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets('registration enforces the minimum password length', (
    tester,
  ) async {
    await pumpFlowBoard(tester, signedIn: false);
    await register(tester, password: 'short', repeat: 'short');
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('registration asks to repeat the password exactly', (
    tester,
  ) async {
    final app = await pumpFlowBoard(tester, signedIn: false);
    await register(tester, repeat: 'correct-hors');
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(app.auth.registered, isEmpty);
  });

  testWidgets('registration leads to sign-in with the email filled in', (
    tester,
  ) async {
    final app = await pumpFlowBoard(tester, signedIn: false);
    await register(tester);

    expect(app.auth.registered.single.email, 'aigerim@example.com');
    expect(app.authCubit.state.isAuthenticated, isFalse);
    expect(app.router.state.matchedLocation, '/login');
    expect(
      find.text('Account created. Sign in with your password.'),
      findsOneWidget,
    );
    expect(find.text('aigerim@example.com'), findsOneWidget);

    await tester.enterText(field('Password'), 'correct-horse');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Aigerim!'), findsOneWidget);
  });
}
