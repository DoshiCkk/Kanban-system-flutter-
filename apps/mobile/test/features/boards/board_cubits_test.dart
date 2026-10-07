import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/cubit/board_cubit.dart';
import 'package:flowboard/features/boards/presentation/cubit/card_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late DriftBoardsRepository repo;
  late FakeWorkspacesRepository workspaces;
  late BoardContent content;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBoardsRepository(db);
    workspaces = FakeWorkspacesRepository();
    final board = await repo.createBoard(
      workspaceId: 'w1',
      title: 'Diploma',
      template: BoardTemplate.basic,
      columnTitles: const ['To do', 'Doing', 'Done'],
    );
    content = (await repo.watchBoard(board.id).first)!;
  });
  tearDown(() => db.close());

  String columnId(int i) => content.columns[i].column.id;

  group('BoardCubit', () {
    test('streams columns and reacts to new cards', () async {
      final cubit = BoardCubit(repo, content.board.id);
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.status == BoardStatus.ready);

      await cubit.createCard(columnId(0), '   ');
      await cubit.createCard(columnId(0), 'Write intro');
      final state = await cubit.stream.firstWhere(
        (s) => s.columns.first.cards.isNotEmpty,
      );
      expect(state.columns.first.cards.single.title, 'Write intro');
    });

    test(
      'moves a card and reports notFound after deleting the board',
      () async {
        final card = await repo.createCard(columnId(0), 'A');
        final cubit = BoardCubit(repo, content.board.id);
        addTearDown(cubit.close);

        await cubit.moveCard(card.id, columnId(2), 0);
        final moved = await cubit.stream.firstWhere(
          (s) => s.columns.length == 3 && s.columns[2].cards.isNotEmpty,
        );
        expect(moved.columns[0].cards, isEmpty);

        await cubit.deleteBoard();
        await cubit.stream.firstWhere((s) => s.status == BoardStatus.notFound);
      },
    );
  });

  group('CardCubit', () {
    late String cardId;

    setUp(() async {
      cardId = (await repo.createCard(columnId(0), 'Card')).id;
    });

    CardCubit build() => CardCubit(
      cardId: cardId,
      cards: repo,
      boards: repo,
      workspaces: workspaces,
    );

    test('loads members and assigns the card', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.members != null);

      await cubit.update(CardPatch(assigneeId: testUser.id));
      final state = await cubit.stream.firstWhere((s) => s.assignee != null);
      expect(state.assignee!.user.name, testUser.name);
    });

    test('members stay unavailable when offline', () async {
      workspaces.failWith = ApiErrorCode.network;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.status == CardStatus.ready);
      await pumpEventQueue();
      expect(cubit.state.members, isNull);
    });

    test('moves through columns until the last one', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.status == CardStatus.ready);

      await cubit.moveToNextColumn();
      await cubit.stream.firstWhere((s) => s.card!.columnId == columnId(1));
      await cubit.moveToNextColumn();
      final last = await cubit.stream.firstWhere(
        (s) => s.card!.columnId == columnId(2),
      );
      expect(last.card!.nextColumn, isNull);
    });

    test('dedupes labels and edits the checklist', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.status == CardStatus.ready);

      await cubit.addLabel('ui');
      await cubit.stream.firstWhere((s) => s.card!.labels.isNotEmpty);
      await cubit.addLabel(' ui ');
      await cubit.addChecklistItem('Draft');
      final withItem = await cubit.stream.firstWhere(
        (s) => s.card!.checklist.isNotEmpty,
      );
      expect(withItem.card!.labels, ['ui']);

      await cubit.toggleChecklistItem(withItem.card!.checklist.single);
      final toggled = await cubit.stream.firstWhere(
        (s) => s.card!.checklist.single.done,
      );
      expect(toggled.card!.checklist.single.text, 'Draft');
    });

    test('reports notFound after delete', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((s) => s.status == CardStatus.ready);
      await cubit.delete();
      await cubit.stream.firstWhere((s) => s.status == CardStatus.notFound);
    });
  });
}
