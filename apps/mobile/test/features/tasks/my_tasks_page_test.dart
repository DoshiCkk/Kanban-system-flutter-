import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/card_page.dart';
import 'package:flowboard/features/tasks/presentation/my_tasks_page.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  /// Four cards assigned to the test user (one done) and one to a teammate.
  Future<TestApp> start(WidgetTester tester) => pumpFlowBoard(
    tester,
    workspaces: const [
      Workspace(
        id: 'w1',
        name: 'Diploma team',
        role: WorkspaceRole.owner,
        memberCount: 2,
      ),
    ],
    seed: (boards) async {
      final board = await boards.createBoard(
        workspaceId: 'w1',
        title: 'Diploma',
        template: BoardTemplate.basic,
        columnTitles: const ['To do', 'Doing', 'Done'],
      );
      final content = (await boards.watchBoard(board.id).first)!;
      final todo = content.columns.first.column.id;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      Future<CardSummary> card(
        String title, {
        DateTime? due,
        String assignee = 'u1',
      }) async {
        final card = await boards.createCard(todo, title);
        await boards.updateCard(
          card.id,
          CardPatch(dueDate: due, assigneeId: assignee),
        );
        return card;
      }

      await card(
        'Overdue essay',
        due: today.subtract(const Duration(days: 2)),
      );
      await card('Slides', due: today);
      await card('Someday');
      await card('Not mine', assignee: 'u2');
      final shipped = await card('Shipped');
      await boards.moveCard(
        shipped.id,
        toColumnId: content.columns.last.column.id,
        toIndex: 0,
      );
    },
  );

  String tileValue(WidgetTester tester, String key) {
    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ),
    );
    return texts.first.data!;
  }

  testWidgets('home sums up my tasks and the tab shows overdue ones', (
    tester,
  ) async {
    await start(tester);

    expect(find.text('Hello, Aigerim!'), findsOneWidget);
    expect(tileValue(tester, 'summary-overdue'), '1');
    expect(tileValue(tester, 'summary-today'), '1');
    expect(tileValue(tester, 'summary-active'), '3');
    expect(find.byTooltip('My tasks: Overdue 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('summary-overdue')));
    await tester.pumpAndSettle();
    expect(find.byType(MyTasksPage), findsOneWidget);
  });

  testWidgets('groups tasks by due date and opens one', (tester) async {
    await start(tester);
    await tester.tap(find.text('My tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Overdue · 1'), findsOneWidget);
    expect(find.text('Today · 1'), findsOneWidget);
    expect(find.text('No due date · 1'), findsOneWidget);
    expect(find.text('Not mine'), findsNothing);
    await tester.scrollUntilVisible(find.text('Done · 1'), 200);
    expect(find.text('Shipped'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Overdue essay'), -200);
    await tester.tap(find.text('Overdue essay'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MyTasksPage), findsOneWidget);
  });

  testWidgets('an empty list explains how to get tasks', (tester) async {
    await pumpFlowBoard(tester);
    await tester.tap(find.text('My tasks'));
    await tester.pumpAndSettle();
    expect(find.text('No tasks assigned to you yet'), findsOneWidget);
  });
}
