import 'dart:async';

import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  /// Signed in, engine running, one local board with 3 queued ops.
  Future<TestApp> setUpOffline(WidgetTester tester) async {
    final app = await pumpFlowBoard(tester);
    app.workspaces.workspaces.add(
      const Workspace(
        id: 'w1',
        name: 'Team',
        role: WorkspaceRole.owner,
        memberCount: 1,
      ),
    );
    await app.boards.createBoard(
      workspaceId: 'w1',
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Done'],
    );
    app.syncApi.offline = true;
    app.syncEngine.start();
    // Debounce + failed cycle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return app;
  }

  /// stop() cancels the engine's timers synchronously; awaiting the rest
  /// (DB stream cancellation) never completes on the fake test clock.
  Future<void> stopEngine(WidgetTester tester, TestApp app) async {
    unawaited(app.syncEngine.stop());
    // Let one-shot UI timers (snackbars, tooltips) run out.
    await tester.pump(const Duration(seconds: 10));
  }

  Finder tooltip(String message) => find.byWidgetPredicate(
    (w) => w is Tooltip && w.message == message,
  );

  testWidgets('indicator shows queued changes and syncs on tap', (
    tester,
  ) async {
    final app = await setUpOffline(tester);
    app.router.go('/workspaces/w1');
    await tester.pumpAndSettle();

    expect(tooltip('3 changes waiting for the network'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    app.syncApi.offline = false;
    await tester.tap(find.byKey(const ValueKey('sync-indicator')));
    await tester.pumpAndSettle();
    expect(tooltip('All changes synced'), findsOneWidget);
    expect(app.syncApi.server.rows['column'], hasLength(2));
    await stopEngine(tester, app);
  });

  testWidgets('sign-out warns about unsynced changes', (tester) async {
    final app = await setUpOffline(tester);
    app.router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('3 changes are not synced yet'), findsOneWidget);

    // Still offline: syncing fails and the user stays signed in.
    await tester.tap(find.text('Sync and sign out'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not sync. Check the connection and try again.'),
      findsOneWidget,
    );
    expect(app.authCubit.state.isAuthenticated, isTrue);

    app.syncApi.offline = false;
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync and sign out'));
    await tester.pumpAndSettle();
    expect(app.syncApi.server.rows['board'], hasLength(1));
    expect(find.text('Welcome back'), findsOneWidget);
    await stopEngine(tester, app);
  });
}
