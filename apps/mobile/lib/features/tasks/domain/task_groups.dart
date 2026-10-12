import 'package:flowboard/features/boards/domain/board_models.dart';

/// Sections of "My tasks", in display order.
enum TaskGroup { overdue, today, upcoming, noDate, done }

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Where [task] belongs on the local calendar day [now]. A due date is the
/// local midnight that starts the due day, so it is overdue from the next
/// day on (as on the board).
TaskGroup groupOf(AssignedCard task, DateTime now) {
  if (task.done) return TaskGroup.done;
  final due = task.card.dueDate;
  if (due == null) return TaskGroup.noDate;
  final day = _day(due.toLocal());
  final today = _day(now);
  if (day.isBefore(today)) return TaskGroup.overdue;
  if (day == today) return TaskGroup.today;
  return TaskGroup.upcoming;
}

/// Non-empty groups in display order; each sorted by due date, then title.
Map<TaskGroup, List<AssignedCard>> groupTasks(
  Iterable<AssignedCard> tasks,
  DateTime now,
) {
  final groups = <TaskGroup, List<AssignedCard>>{};
  for (final task in tasks) {
    groups.putIfAbsent(groupOf(task, now), () => []).add(task);
  }
  int byDue(AssignedCard a, AssignedCard b) {
    final da = a.card.dueDate;
    final db = b.card.dueDate;
    if (da != null && db != null && da != db) return da.compareTo(db);
    return a.card.title.toLowerCase().compareTo(b.card.title.toLowerCase());
  }

  return {
    for (final group in TaskGroup.values)
      if (groups[group] case final list?) group: list..sort(byDue),
  };
}
