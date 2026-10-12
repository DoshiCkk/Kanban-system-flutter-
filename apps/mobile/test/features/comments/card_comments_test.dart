import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/comments/domain/comments_repository.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const bob = MemberUser(id: 'u2', email: 'bob@example.com', name: 'Bob Marley');

void main() {
  late String cardId;

  Future<void> openCard(WidgetTester tester) async {
    late String boardId;
    final app = await pumpFlowBoard(
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
          columnTitles: const ['To do', 'Done'],
        );
        boardId = board.id;
        final content = (await boards.watchBoard(board.id).first)!;
        cardId = (await boards.createCard(
          content.columns.first.column.id,
          'Intro',
        )).id;
      },
    );
    app.workspaces.teammates.add(bob);
    app.router.go('/workspaces/w1/boards/$boardId/cards/$cardId');
    await tester.pumpAndSettle();
  }

  final input = find.byKey(const ValueKey('comment-input'));

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('comment-send')));
    await tester.pumpAndSettle();
  }

  /// The composer is at the end of the lazily built card page.
  Future<void> scrollToComposer(WidgetTester tester) =>
      tester.scrollUntilVisible(
        input,
        300,
        scrollable: find.byType(Scrollable).first,
      );

  String inputText(WidgetTester tester) =>
      tester.widget<TextField>(input).controller!.text;

  testWidgets('mentions a teammate picked from the @ suggestions', (
    tester,
  ) async {
    await openCard(tester);
    await scrollToComposer(tester);
    expect(
      find.text('No comments yet. Type @ to mention a teammate.'),
      findsOneWidget,
    );

    await tester.enterText(input, 'Ask @mar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mention-u2')));
    await tester.pumpAndSettle();
    expect(inputText(tester), 'Ask @Bob Marley ');
    expect(find.byKey(const ValueKey('mention-u2')), findsNothing);

    await send(tester);
    expect(inputText(tester), isEmpty);
    // Saved trimmed.
    final text = tester.widget<Text>(find.text('Ask @Bob Marley'));
    final spans = (text.textSpan! as TextSpan).children!;
    final mention = spans[1] as TextSpan;
    expect(mention.text, '@Bob Marley');
    expect(mention.style?.fontWeight, FontWeight.w600);
    // Written offline-first: waiting for the server.
    expect(find.byIcon(Icons.schedule), findsOneWidget);

    final saved = await tester.runAsync(
      () => getIt<CommentsRepository>().watchComments(cardId).first,
    );
    expect(saved!.single.mentions, ['u2']);
  });

  testWidgets('edits and deletes an own comment', (tester) async {
    await openCard(tester);
    await scrollToComposer(tester);
    await tester.enterText(input, 'Draft');
    await send(tester);

    await tester.tap(find.byTooltip('Comment actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Editing comment'), findsOneWidget);
    expect(inputText(tester), 'Draft');

    await tester.enterText(input, 'Final');
    await send(tester);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Editing comment'), findsNothing);

    await tester.tap(find.byTooltip('Comment actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this comment?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Final'), findsNothing);
    expect(
      find.text('No comments yet. Type @ to mention a teammate.'),
      findsOneWidget,
    );
  });
}
