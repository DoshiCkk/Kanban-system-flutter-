import 'package:flowboard/features/boards/domain/board_filter.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 10, 15);

  CardSummary card(
    String title, {
    CardPriority priority = CardPriority.medium,
    List<String> labels = const [],
    DateTime? due,
    String? assignee,
  }) => CardSummary(
    id: title,
    columnId: 'c1',
    title: title,
    priority: priority,
    position: 'a0',
    labels: labels,
    dueDate: due,
    assigneeId: assignee,
  );

  final cards = [
    card('Write the intro', labels: ['thesis'], assignee: 'u1'),
    card('Survey', priority: CardPriority.high, due: DateTime(2026, 3, 9)),
    card('Slides', labels: ['defense'], due: DateTime(2026, 3, 10)),
  ];

  List<String> matching(BoardFilter filter) => [
    for (final c in cards)
      if (filter.matches(c, userId: 'u1', now: now)) c.title,
  ];

  test('an empty filter matches everything and is inactive', () {
    const filter = BoardFilter(query: '  ');
    expect(filter.isActive, isFalse);
    expect(matching(filter), hasLength(3));
  });

  test('search looks at titles and labels, ignoring case', () {
    expect(matching(const BoardFilter(query: 'INTRO')), ['Write the intro']);
    expect(matching(const BoardFilter(query: 'defen')), ['Slides']);
  });

  test('criteria combine with AND, options within one with OR', () {
    expect(matching(const BoardFilter(onlyMine: true)), ['Write the intro']);
    // Due today is not overdue yet.
    expect(matching(const BoardFilter(overdue: true)), ['Survey']);
    expect(
      matching(
        const BoardFilter(
          priorities: {CardPriority.high, CardPriority.medium},
          labels: {'thesis', 'defense'},
        ),
      ),
      ['Write the intro', 'Slides'],
    );
    expect(matching(const BoardFilter(onlyMine: true, overdue: true)), isEmpty);
  });

  test('counts sheet criteria but not the search query', () {
    const filter = BoardFilter(
      query: 'x',
      overdue: true,
      priorities: {CardPriority.low},
      labels: {'a', 'b'},
    );
    expect(filter.criteriaCount, 4);
    expect(filter.isActive, isTrue);
  });
}
