import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/cubit/board_cubit.dart';
import 'package:flowboard/features/boards/presentation/widgets/board_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Filter chips for the board; changes apply at once.
class BoardFilterSheet extends StatelessWidget {
  const BoardFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<BoardCubit>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const BoardFilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<BoardCubit>();
    final state = context.watch<BoardCubit>().state;
    final filter = state.filter;
    final labels = state.labels;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: theme.textTheme.titleSmall),
    );

    Set<T> toggled<T>(Set<T> set, T value) =>
        set.contains(value) ? ({...set}..remove(value)) : {...set, value};

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.boardFilter, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.filterOnlyMine),
                  selected: filter.onlyMine,
                  onSelected: (v) =>
                      cubit.setFilter(filter.copyWith(onlyMine: v)),
                ),
                FilterChip(
                  label: Text(l10n.filterOverdue),
                  selected: filter.overdue,
                  onSelected: (v) =>
                      cubit.setFilter(filter.copyWith(overdue: v)),
                ),
              ],
            ),
            section(l10n.cardPriority),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in CardPriority.values.reversed)
                  FilterChip(
                    avatar: Icon(priorityIcon(p), size: 18),
                    label: Text(l10n.priority(p)),
                    selected: filter.priorities.contains(p),
                    onSelected: (_) => cubit.setFilter(
                      filter.copyWith(
                        priorities: toggled(filter.priorities, p),
                      ),
                    ),
                  ),
              ],
            ),
            if (labels.isNotEmpty) ...[
              section(l10n.cardLabels),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in labels)
                    FilterChip(
                      label: Text(label),
                      selected: filter.labels.contains(label),
                      onSelected: (_) => cubit.setFilter(
                        filter.copyWith(labels: toggled(filter.labels, label)),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: filter.criteriaCount == 0
                        ? null
                        : cubit.clearFilters,
                    child: Text(l10n.filterReset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.filterShow),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 of 10 cards" above a filtered board, with a reset button.
class FilterSummaryBar extends StatelessWidget {
  const FilterSummaryBar({
    required this.shown,
    required this.total,
    required this.onReset,
    super.key,
  });

  final int shown;
  final int total;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.filterSummary(shown, total),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSecondaryContainer,
              ),
              child: Text(l10n.filterReset),
            ),
          ],
        ),
      ),
    );
  }
}
