import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('creates a workspace from the bottom sheet with Enter', (
    tester,
  ) async {
    final app = await pumpFlowBoard(tester);

    await tester.tap(find.text('New workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Diploma team');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Diploma team'), findsOneWidget);
    expect(find.text('Owner · 1 member'), findsOneWidget);
    expect(app.workspaces.workspaces.single.name, 'Diploma team');
  });

  testWidgets('shows an error with retry when loading fails', (tester) async {
    final app = await pumpFlowBoard(tester);
    app.workspaces.failWith = ApiErrorCode.network;
    final element = tester.element(find.byType(Scaffold).first);
    await BlocProvider.of<WorkspacesCubit>(element).load();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No connection to the server. Check the internet and try again.',
      ),
      findsOneWidget,
    );
    app.workspaces
      ..failWith = null
      ..workspaces.add(
        const Workspace(
          id: 'w9',
          name: 'Recovered',
          role: WorkspaceRole.member,
          memberCount: 2,
        ),
      );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  group('parseInviteToken', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

    test('accepts deep links, https links and bare tokens', () {
      expect(parseInviteToken('flowboard://app/invite/$token'), token);
      expect(parseInviteToken(' https://x.dev/invite/$token?ref=1 '), token);
      expect(parseInviteToken(token), token);
    });

    test('rejects garbage', () {
      expect(parseInviteToken(''), isNull);
      expect(parseInviteToken('hello world'), isNull);
      expect(parseInviteToken('https://example.com/boards/1'), isNull);
    });
  });
}
