import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/board_page.dart';
import 'package:flowboard/features/boards/presentation/card_page.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  late TestApp app;
  late BoardContent content;

  Future<void> openBoard(WidgetTester tester, {List<String>? cards}) async {
    app = await pumpFlowBoard(tester);
    app.workspaces.workspaces.add(
      const Workspace(
        id: 'w1',
        name: 'Diploma team',
        role: WorkspaceRole.owner,
        memberCount: 1,
      ),
    );
    // Real DB I/O must run outside the fake-async test zone.
    await tester.runAsync(() async {
      final board = await app.boards.createBoard(
        workspaceId: 'w1',
        title: 'Diploma',
        template: BoardTemplate.basic,
        columnTitles: const ['To do', 'Doing', 'Done'],
      );
      final todo = (await app.boards.watchBoard(board.id).first)!;
      for (final title in cards ?? const <String>[]) {
        await app.boards.createCard(todo.columns.first.column.id, title);
      }
      content = (await app.boards.watchBoard(board.id).first)!;
    });
    app.router.go('/workspaces/w1/boards/${content.board.id}');
    await tester.pumpAndSettle();
  }

  List<String> cardsIn(int column) =>
      content.columns[column].cards.map((c) => c.title).toList();

  Future<void> reload(WidgetTester tester) => tester.runAsync(() async {
    content = (await app.boards.watchBoard(content.board.id).first)!;
  });

  /// Tab chips are labelled "<title>  <count>".
  Finder tab(String title, int count) => find.text('$title  $count');

  testWidgets('shows one column per page with counted tabs', (tester) async {
    await openBoard(tester, cards: ['Intro', 'Survey']);

    expect(find.byType(BoardPage), findsOneWidget);
    expect(tab('To do', 2), findsOneWidget);
    expect(tab('Doing', 0), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);

    await tester.fling(find.text('Intro'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Intro'), findsNothing);

    await tester.tap(tab('To do', 2));
    await tester.pumpAndSettle();
    expect(find.text('Intro'), findsOneWidget);
  });

  testWidgets('quick create keeps the sheet open after Enter', (tester) async {
    await openBoard(tester);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await reload(tester);
    expect(cardsIn(0), ['First', 'Second']);
  });

  testWidgets('card page moves the card to the next column', (tester) async {
    await openBoard(tester, cards: ['Intro']);

    await tester.tap(find.text('Intro'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPage), findsOneWidget);

    await tester.tap(find.text('Move to “Doing”'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to “Done”'));
    await tester.pumpAndSettle();

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Already in the last column'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    await reload(tester);
    expect(cardsIn(2), ['Intro']);
  });

  testWidgets('long-press drag onto a tab moves the card there', (
    tester,
  ) async {
    await openBoard(tester, cards: ['Intro', 'Survey']);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Intro')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(tab('Doing', 0)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await reload(tester);
    expect(cardsIn(0), ['Survey']);
    expect(cardsIn(1), ['Intro']);
    expect(tab('Doing', 1), findsOneWidget);
  });

  testWidgets('holding a card at the screen edge pages to the next column', (
    tester,
  ) async {
    await openBoard(tester, cards: ['Intro']);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final start = tester.getCenter(find.text('Intro'));

    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(width - 10, start.dy));
    await tester.pump(BoardPage.edgeDelay);
    await tester.pump(const Duration(milliseconds: 300));
    // Back to the middle to stop paging, then drop into "Doing".
    await gesture.moveTo(Offset(width / 2, start.dy + 40));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    await reload(tester);
    expect(cardsIn(0), isEmpty);
    expect(cardsIn(1), ['Intro']);
  });
}
