import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mid-afternoon, so "today" is unambiguous.
  final now = DateTime(2026, 3, 10, 15);

  AssignedCard task(String title, {DateTime? due, bool done = false}) =>
      AssignedCard(
        card: CardSummary(
          id: title,
          columnId: 'c1',
          title: title,
          priority: CardPriority.medium,
          position: 'a0',
          dueDate: due,
          assigneeId: 'u1',
        ),
        workspaceId: 'w1',
        boardId: 'b1',
        boardTitle: 'Diploma',
        columnTitle: done ? 'Done' : 'To do',
        done: done,
      );

  test('a due date is overdue from the next day on', () {
    expect(
      groupOf(task('a', due: DateTime(2026, 3, 9)), now),
      TaskGroup.overdue,
    );
    expect(
      groupOf(task('b', due: DateTime(2026, 3, 10)), now),
      TaskGroup.today,
    );
    expect(
      groupOf(task('c', due: DateTime(2026, 3, 11)), now),
      TaskGroup.upcoming,
    );
    expect(groupOf(task('d'), now), TaskGroup.noDate);
  });

  test('done wins over an old due date', () {
    expect(
      groupOf(task('a', due: DateTime(2026, 1, 5), done: true), now),
      TaskGroup.done,
    );
  });

  test('keeps non-empty groups in order, sorted by due date then title', () {
    final groups = groupTasks([
      task('Zeta'),
      task('Late', due: DateTime(2026, 3, 2)),
      task('Later', due: DateTime(2026, 3, 20)),
      task('Soon', due: DateTime(2026, 3, 12)),
      task('alpha'),
      task('Shipped', done: true),
    ], now);

    expect(groups.keys, [
      TaskGroup.overdue,
      TaskGroup.upcoming,
      TaskGroup.noDate,
      TaskGroup.done,
    ]);
    List<String> titles(TaskGroup g) =>
        groups[g]!.map((t) => t.card.title).toList();
    expect(titles(TaskGroup.upcoming), ['Soon', 'Later']);
    expect(titles(TaskGroup.noDate), ['alpha', 'Zeta']);
  });
}
