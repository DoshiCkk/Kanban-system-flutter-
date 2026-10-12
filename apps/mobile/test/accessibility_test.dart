import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

/// Flutter's accessibility guidelines on the main screens, in both themes:
/// tap targets (48 dp Android / 44 pt iOS), labels on everything tappable
/// and WCAG AA text contrast.
void main() {
  late TestApp app;
  late BoardContent board;

  /// A typical phone: 390 × 844 logical pixels.
  void usePhone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> seed(WidgetTester tester, ThemeMode theme) async {
    usePhone(tester);
    app = await pumpFlowBoard(
      tester,
      themeMode: theme,
      workspaces: const [
        Workspace(
          id: 'w1',
          name: 'Diploma team',
          role: WorkspaceRole.owner,
          memberCount: 1,
        ),
      ],
      seed: (boards) async {
        final created = await boards.createBoard(
          workspaceId: 'w1',
          title: 'Diploma',
          template: BoardTemplate.basic,
          columnTitles: const ['To do', 'Doing', 'Done'],
        );
        final content = (await boards.watchBoard(created.id).first)!;
        final todo = content.columns.first.column.id;
        final intro = await boards.createCard(todo, 'Write the intro');
        await boards.updateCard(
          intro.id,
          CardPatch(
            priority: CardPriority.high,
            labels: const ['thesis', 'urgent'],
            dueDate: DateTime(2026, 1, 15),
            assigneeId: 'u1',
          ),
        );
        final item = await boards.addChecklistItem(intro.id, 'Outline');
        await boards.updateChecklistItem(item.id, done: true);
        await boards.addChecklistItem(intro.id, 'Draft');
        final survey = await boards.createCard(todo, 'Survey');
        await boards.updateCard(
          survey.id,
          const CardPatch(priority: CardPriority.low),
        );
        board = (await boards.watchBoard(created.id).first)!;
      },
    );
  }

  Future<void> go(WidgetTester tester, String location) async {
    app.router.go(location);
    await tester.pumpAndSettle();
  }

  String boardPath() => '/workspaces/w1/boards/${board.board.id}';

  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    group('${theme.name} theme', () {
      testWidgets('workspaces and boards lists', (tester) async {
        final semantics = tester.ensureSemantics();
        await seed(tester, theme);
        expect(find.text('Diploma team'), findsOneWidget);
        expect(find.text('Hello, Aigerim!'), findsOneWidget);
        await expectAccessible(tester);

        await go(tester, '/workspaces/w1');
        expect(find.text('Diploma'), findsOneWidget);
        await expectAccessible(tester);
        semantics.dispose();
      });

      testWidgets('board', (tester) async {
        final semantics = tester.ensureSemantics();
        await seed(tester, theme);
        await go(tester, boardPath());
        expect(find.text('Write the intro'), findsOneWidget);
        await expectAccessible(tester);
        semantics.dispose();
      });

      testWidgets('card', (tester) async {
        final semantics = tester.ensureSemantics();
        await seed(tester, theme);
        final intro = board.columns.first.cards.first;
        await go(tester, '${boardPath()}/cards/${intro.id}');
        await expectAccessible(tester);
        semantics.dispose();
      });

      testWidgets('my tasks, profile and settings', (tester) async {
        final semantics = tester.ensureSemantics();
        await seed(tester, theme);
        await go(tester, '/tasks');
        expect(find.text('Write the intro'), findsOneWidget);
        await expectAccessible(tester);

        await go(tester, '/profile');
        expect(find.text('aigerim@example.com'), findsOneWidget);
        await expectAccessible(tester);

        await go(tester, '/profile/settings');
        await expectAccessible(tester);
        semantics.dispose();
      });

      testWidgets('board search and filters', (tester) async {
        final semantics = tester.ensureSemantics();
        await seed(tester, theme);
        await go(tester, boardPath());
        await tester.tap(find.byTooltip('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Overdue'));
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.tap(find.text('Show cards'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 2 cards shown'), findsOneWidget);
        // The badge number does not replace the button's name.
        final button = tester
            .getSemantics(find.byTooltip('Filter: 1 active'))
            .getSemanticsData();
        expect(button.label, isEmpty);
        expect(button.tooltip, 'Filter: 1 active');
        await expectAccessible(tester);
        semantics.dispose();
      });
    });
  }

  testWidgets('main screens lay out at 200 % text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(tester, ThemeMode.light);
    final context = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
    final intro = board.columns.first.cards.first;
    // A RenderFlex overflow anywhere fails the test.
    for (final path in [
      '/workspaces/w1',
      boardPath(),
      '${boardPath()}/cards/${intro.id}',
      '/workspaces/w1/members',
      '/tasks',
      '/profile',
      '/profile/settings',
    ]) {
      await go(tester, path);
    }
  });

  testWidgets('sign-in screen', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhone(tester);
    await pumpFlowBoard(tester, signedIn: false);
    expect(find.text('Welcome back'), findsOneWidget);
    await expectAccessible(tester);
    semantics.dispose();
  });

  testWidgets('cards speak their details and can be moved without '
      'dragging', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed(tester, ThemeMode.light);
    await go(tester, boardPath());

    final data = tester
        .getSemantics(find.text('Write the intro'))
        .getSemanticsData();
    expect(
      data.label,
      allOf(
        contains('Write the intro'),
        contains('Overdue, was due Jan 15'),
        contains('Checklist: 1 of 2 done'),
        contains('Has an assignee'),
      ),
    );
    expect(data.hint, 'Long press to move');
    final actions = [
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(actions, ['Move to “Doing”']);

    // A screen reader user moves the card without dragging.
    tester.semantics.performAction(
      find.semantics.byLabel(RegExp('Write the intro')),
      SemanticsAction.customAction,
      args: data.customSemanticsActionIds!.first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Write the intro'), findsNothing);
    expect(find.text('Doing  1'), findsOneWidget);
    semantics.dispose();
  });
}
