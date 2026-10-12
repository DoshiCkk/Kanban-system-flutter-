import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  Future<TestApp> openProfile(WidgetTester tester) async {
    final app = await pumpFlowBoard(
      tester,
      user: testUser.copyWith(createdAt: DateTime(2026, 2, 3)),
      workspaces: const [
        Workspace(
          id: 'w1',
          name: 'Diploma team',
          role: WorkspaceRole.owner,
          memberCount: 1,
        ),
        Workspace(
          id: 'w2',
          name: 'Hackathon',
          role: WorkspaceRole.member,
          memberCount: 4,
        ),
      ],
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.tap(find.text('Change name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows who I am and my numbers', (tester) async {
    await openProfile(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
    expect(find.text('aigerim@example.com'), findsOneWidget);
    expect(find.text('Member since February 3, 2026'), findsOneWidget);
    final workspaces = find.ancestor(
      of: find.text('Workspaces'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: workspaces, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('renames the user everywhere', (tester) async {
    final app = await openProfile(tester);

    await rename(tester, '  Dana Nur  ');
    expect(find.text('Name updated'), findsOneWidget);
    expect(find.text('Dana Nur'), findsOneWidget);
    expect(find.text('DN'), findsOneWidget);
    expect(app.authCubit.state.user!.name, 'Dana Nur');

    // Home greets by the first name.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Dana!'), findsOneWidget);
  });

  testWidgets('keeps the old name when saving fails', (tester) async {
    final app = await openProfile(tester);
    app.auth.failWith = ApiErrorCode.network;

    await rename(tester, 'Someone else');
    const offline =
        'No connection to the server. Check the internet and try again.';
    expect(find.text(offline), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
  });

  testWidgets('opens language and theme settings', (tester) async {
    final app = await openProfile(tester);
    await tester.tap(find.text('Language and theme'));
    await tester.pumpAndSettle();
    expect(app.router.state.matchedLocation, '/profile/settings');
    expect(find.text('Settings'), findsOneWidget);
  });
}
