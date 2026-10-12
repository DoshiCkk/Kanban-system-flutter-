import 'package:flowboard/features/boards/presentation/board_page.dart';
import 'package:flowboard/features/boards/presentation/boards_page.dart';
import 'package:flowboard/features/boards/presentation/card_page.dart';
import 'package:flowboard/features/profile/presentation/profile_page.dart';
import 'package:flowboard/features/splash/presentation/splash_screen.dart';
import 'package:flowboard/features/tasks/presentation/my_tasks_page.dart';
import 'package:flowboard/features/workspaces/presentation/workspaces_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

/// The whole path a new user takes, as shown at the defense:
/// splash → sign-up → sign-in → home → tabs → profile → boards → sign-out.
void main() {
  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('a new user goes from the splash to sign-out', (tester) async {
    final app = await pumpFlowBoard(
      tester,
      signedIn: false,
      splash: const Duration(milliseconds: 1200),
    );

    // 1. Splash: logo, name, tagline.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('FlowBoard'), findsOneWidget);
    expect(find.text('Kanban for small teams'), findsOneWidget);
    expect(find.bySemanticsLabel('FlowBoard'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);

    // 2. Registration, then back to sign-in with the e-mail filled in.
    await tapText(tester, 'No account yet? Create one');
    await tester.enterText(field('Your name'), 'Dana Sadykova');
    await tester.enterText(field('Email'), 'dana@example.com');
    await tester.enterText(field('Password'), 'correct-horse');
    await tester.enterText(field('Repeat password'), 'correct-horse');
    await tapText(tester, 'Create account');
    expect(
      find.text('Account created. Sign in with your password.'),
      findsOneWidget,
    );
    expect(app.authCubit.state.isAuthenticated, isFalse);

    // 3. Sign-in.
    await tester.enterText(field('Password'), 'correct-horse');
    await tapText(tester, 'Sign in');
    expect(app.authCubit.state.user?.email, 'dana@example.com');

    // 4. Home: greeting, task summary, workspaces.
    expect(find.byType(WorkspacesPage), findsOneWidget);
    expect(find.text('Hello, Dana Sadykova!'), findsOneWidget);
    expect(find.text('Assigned to me'), findsOneWidget);
    expect(find.text('No workspaces yet'), findsOneWidget);

    // 5. Bottom navigation.
    await tapText(tester, 'My tasks');
    expect(find.byType(MyTasksPage), findsOneWidget);
    expect(find.text('No tasks assigned to you yet'), findsOneWidget);

    await tapText(tester, 'Profile');
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Dana Sadykova'), findsOneWidget);
    expect(find.text('dana@example.com'), findsOneWidget);
    expect(find.text('DS'), findsOneWidget);

    // 6. Main section: workspace → board → card.
    await tapText(tester, 'Home');
    await tapText(tester, 'New workspace');
    await tester.enterText(find.byType(TextField), 'Diploma team');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tapText(tester, 'Diploma team');
    expect(find.byType(BoardsPage), findsOneWidget);
    // Full screen above the tabs.
    expect(find.text('Profile'), findsNothing);

    await tapText(tester, 'New board');
    await tester.enterText(find.byType(TextField), 'Diploma');
    await tapText(tester, 'Create');
    expect(find.byType(BoardPage), findsOneWidget);
    expect(find.text('To do  0'), findsOneWidget);

    await tapText(tester, 'Task');
    await tester.enterText(find.byType(TextField), 'Write the intro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // Closes the quick sheet.
    await tester.pumpAndSettle();
    expect(find.text('To do  1'), findsOneWidget);

    await tapText(tester, 'Write the intro');
    expect(find.byType(CardPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WorkspacesPage), findsOneWidget);

    // 7. Sign-out from the profile.
    await tapText(tester, 'Profile');
    final signOut = find.byKey(const ValueKey('logout'));
    await tester.ensureVisible(signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(app.authCubit.state.isAuthenticated, isFalse);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
