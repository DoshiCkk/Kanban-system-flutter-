import 'package:flowboard/core/notifications/notification_service.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/card_page.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  late TestApp app;
  late PushTarget target;

  Future<void> start(WidgetTester tester) async {
    app = await pumpFlowBoard(tester);
    app.workspaces.workspaces.add(
      const Workspace(
        id: 'w1',
        name: 'Diploma team',
        role: WorkspaceRole.owner,
        memberCount: 1,
      ),
    );
    await tester.runAsync(() async {
      final board = await app.boards.createBoard(
        workspaceId: 'w1',
        title: 'Diploma',
        template: BoardTemplate.basic,
        columnTitles: const ['To do', 'Done'],
      );
      final content = (await app.boards.watchBoard(board.id).first)!;
      final card = await app.boards.createCard(
        content.columns.first.column.id,
        'Intro',
      );
      target = PushTarget(
        workspaceId: 'w1',
        boardId: board.id,
        cardId: card.id,
      );
    });
  }

  testWidgets('a tapped push opens its card', (tester) async {
    await start(tester);
    app.notifications.openedPushes.add(target);
    await tester.pumpAndSettle();
    expect(find.byType(CardPage), findsOneWidget);
    expect(find.text('Intro'), findsWidgets);
  });

  testWidgets('a push in the open app shows a banner that opens the card', (
    tester,
  ) async {
    await start(tester);
    app.notifications.foregroundPushes.add(
      ForegroundPush(
        title: 'Due tomorrow',
        body: '“Intro” on Diploma',
        target: target,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('“Intro” on Diploma'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPage), findsOneWidget);
  });

  testWidgets('push texts follow the UI language', (tester) async {
    await start(tester);
    expect(app.notifications.locales.last, 'en');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(app.notifications.locales.last, 'ru');
  });
}
