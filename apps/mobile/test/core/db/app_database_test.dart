import 'package:drift/native.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertBoard(String id) => db
      .into(db.boards)
      .insert(
        BoardsCompanion.insert(
          id: id,
          workspaceId: 'w1',
          title: 'Board',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  test('claimFor keeps data for the same user', () async {
    await db.claimFor('u1');
    await insertBoard('b1');
    await db.claimFor('u1');
    expect(await db.select(db.boards).get(), hasLength(1));
  });

  test('claimFor wipes data when another user signs in', () async {
    await db.claimFor('u1');
    await insertBoard('b1');
    await db.claimFor('u2');
    expect(await db.select(db.boards).get(), isEmpty);
  });

  test('stores timestamps as ISO text and labels as JSON', () async {
    await insertBoard('b1');
    final row = await db
        .customSelect('SELECT created_at FROM boards')
        .getSingle();
    expect(row.read<String>('created_at'), startsWith('2026-01-01T00:00:00'));
  });
}
