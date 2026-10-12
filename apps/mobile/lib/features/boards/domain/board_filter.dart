import 'package:equatable/equatable.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';

/// Search and filters on a board. Empty criteria match everything.
class BoardFilter extends Equatable {
  const BoardFilter({
    this.query = '',
    this.onlyMine = false,
    this.overdue = false,
    this.priorities = const {},
    this.labels = const {},
  });

  /// Matched against the title and labels, case-insensitively.
  final String query;
  final bool onlyMine;
  final bool overdue;
  final Set<CardPriority> priorities;
  final Set<String> labels;

  bool get isActive => query.trim().isNotEmpty || criteriaCount > 0;

  /// Filters chosen in the filter sheet (the search query not included).
  int get criteriaCount =>
      (onlyMine ? 1 : 0) +
      (overdue ? 1 : 0) +
      priorities.length +
      labels.length;

  /// [now] is the local time; a due date is the local midnight that starts
  /// the due day, so a card is overdue from the next day on.
  bool matches(CardSummary card, {required String userId, DateTime? now}) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !card.title.toLowerCase().contains(q) &&
        !card.labels.any((l) => l.toLowerCase().contains(q))) {
      return false;
    }
    if (onlyMine && card.assigneeId != userId) return false;
    if (overdue) {
      final due = card.dueDate?.toLocal();
      final today = now ?? DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      if (due == null || !due.isBefore(start)) return false;
    }
    if (priorities.isNotEmpty && !priorities.contains(card.priority)) {
      return false;
    }
    if (labels.isNotEmpty && !card.labels.any(labels.contains)) return false;
    return true;
  }

  BoardFilter copyWith({
    String? query,
    bool? onlyMine,
    bool? overdue,
    Set<CardPriority>? priorities,
    Set<String>? labels,
  }) => BoardFilter(
    query: query ?? this.query,
    onlyMine: onlyMine ?? this.onlyMine,
    overdue: overdue ?? this.overdue,
    priorities: priorities ?? this.priorities,
    labels: labels ?? this.labels,
  );

  @override
  List<Object?> get props => [query, onlyMine, overdue, priorities, labels];
}
