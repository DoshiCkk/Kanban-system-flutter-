import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/features/comments/data/drift_comments_repository.dart';
import 'package:flowboard/features/comments/presentation/cubit/comments_cubit.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const me = MemberUser(id: 'u1', email: 'me@example.com', name: 'Aigerim');
const bob = MemberUser(id: 'u2', email: 'bob@example.com', name: 'Bob');

void main() {
  late AppDatabase db;
  late DriftCommentsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCommentsRepository(db);
  });
  tearDown(() => db.close());

  Future<List<(String, String, Map<String, dynamic>)>> outbox() async => [
    for (final op in await db.select(db.outbox).get())
      (
        op.operation,
        op.entityId,
        jsonDecode(op.payload) as Map<String, dynamic>,
      ),
  ];

  group('DriftCommentsRepository', () {
    test('adds a comment with its create op', () async {
      final comment = await repo.addComment(
        cardId: 'c1',
        authorId: 'u1',
        text: ' Hi @Bob ',
        mentions: const ['u2'],
      );
      expect(comment.text, 'Hi @Bob');
      expect(comment.pending, isTrue);
      final [(operation, id, payload)] = await outbox();
      expect(operation, 'create');
      expect(id, comment.id);
      expect(payload, {
        'cardId': 'c1',
        'text': 'Hi @Bob',
        'mentions': ['u2'],
        'createdAt': comment.createdAt.toUtc().toIso8601String(),
      });
    });

    test('an edit sends only the changed fields', () async {
      final comment = await repo.addComment(
        cardId: 'c1',
        authorId: 'u1',
        text: 'Hi @Bob',
        mentions: const ['u2'],
      );
      await repo.editComment(
        comment.id,
        text: 'Hi @Bob',
        mentions: const ['u2'],
      );
      await repo.editComment(
        comment.id,
        text: 'Hello @Bob',
        mentions: const ['u2'],
      );
      await repo.editComment(comment.id, text: 'Hello', mentions: const []);
      final ops = await outbox();
      expect(ops.map((o) => o.$3), [
        isA<Map<String, dynamic>>(),
        {'text': 'Hello @Bob'},
        {'text': 'Hello', 'mentions': <String>[]},
      ]);
    });

    test('lists live comments oldest first', () async {
      final first = await repo.addComment(
        cardId: 'c1',
        authorId: 'u1',
        text: 'First',
        mentions: const [],
      );
      await repo.addComment(
        cardId: 'c1',
        authorId: 'u1',
        text: 'Second',
        mentions: const [],
      );
      await repo.addComment(
        cardId: 'c2',
        authorId: 'u1',
        text: 'Elsewhere',
        mentions: const [],
      );
      await repo.deleteComment(first.id);
      final comments = await repo.watchComments('c1').first;
      expect(comments.map((c) => c.text), ['Second']);
      expect((await outbox()).last.$1, 'delete');
    });
  });

  group('CommentsCubit', () {
    late CommentsCubit cubit;

    setUp(() {
      cubit = CommentsCubit(cardId: 'c1', currentUserId: 'u1', comments: repo);
    });
    tearDown(() => cubit.close());

    Future<void> settle() => pumpEventQueue();

    test('resolves @mentions from the member list', () async {
      expect(await cubit.submit('  ', const [me, bob]), isFalse);
      expect(await cubit.submit('Ping @Bob', const [me, bob]), isTrue);
      await settle();
      final comment = cubit.state.comments.single;
      expect(comment.authorId, 'u1');
      expect(comment.mentions, ['u2']);
    });

    test('edits only own comments and keeps mentions when offline', () async {
      await cubit.submit('Ping @Bob', const [me, bob]);
      await repo.addComment(
        cardId: 'c1',
        authorId: 'u2',
        text: 'Not yours',
        mentions: const [],
      );
      await settle();
      final [mine, theirs] = cubit.state.comments;

      cubit.startEditing(theirs);
      expect(cubit.state.editing, isNull);
      cubit.startEditing(mine);
      expect(cubit.state.editing, mine);

      // No member list: the name cannot be checked, so mentions stay.
      await cubit.submit('Ping @Bob again', null);
      await settle();
      expect(cubit.state.editing, isNull);
      expect(cubit.state.comments.first.text, 'Ping @Bob again');
      expect(cubit.state.comments.first.mentions, ['u2']);

      await cubit.delete(theirs);
      await cubit.delete(mine);
      await settle();
      expect(cubit.state.comments.map((c) => c.text), ['Not yours']);
    });
  });
}
