import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/sync_indicator.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/core/widgets/skeleton.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/widgets/board_labels.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flowboard/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

extension TaskGroupL10n on AppLocalizations {
  String taskGroup(TaskGroup group) => switch (group) {
    TaskGroup.overdue => taskGroupOverdue,
    TaskGroup.today => taskGroupToday,
    TaskGroup.upcoming => taskGroupUpcoming,
    TaskGroup.noDate => taskGroupNoDate,
    TaskGroup.done => taskGroupDone,
  };
}

/// Cards assigned to me on every board, by due date.
class MyTasksPage extends StatelessWidget {
  const MyTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMyTasks),
        actions: const [SyncIndicator()],
      ),
      body: BlocBuilder<MyTasksCubit, MyTasksState>(
        builder: (context, state) {
          if (state.loading) return const ListSkeleton();
          if (state.isEmpty) {
            return MessageView(
              icon: Icons.task_alt,
              title: l10n.myTasksEmptyTitle,
              body: l10n.myTasksEmptyBody,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final MapEntry(key: group, value: tasks)
                  in state.groups.entries) ...[
                _GroupHeader(title: l10n.taskGroup(group), count: tasks.length),
                for (final task in tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TaskTile(task: task),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          '$title · $count',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// One assigned card: title, where it is, due date and priority.
class TaskTile extends StatelessWidget {
  const TaskTile({required this.task, super.key});

  final AssignedCard task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = task.card;
    final due = card.dueDate;
    final overdue = groupOf(task, DateTime.now()) == TaskGroup.overdue;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dueText = due == null
        ? null
        : DateFormat.MMMd(locale).format(due.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('task-${card.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          task.done ? Icons.check_circle : priorityIcon(card.priority),
          color: task.done
              ? successColor(scheme)
              : priorityColor(card.priority, scheme),
          semanticLabel: task.done
              ? l10n.taskGroupDone
              : l10n.priority(card.priority),
        ),
        title: Text(
          card.title,
          style: task.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: scheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${task.boardTitle} · ${task.columnTitle}'),
              if (dueText != null)
                TextSpan(
                  text: ' · $dueText',
                  semanticsLabel: overdue
                      ? l10n.cardOverdueSemantics(dueText)
                      : l10n.cardDueSemantics(dueText),
                  style: overdue
                      ? TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(
          AppRoutes.task,
          pathParameters: {'cardId': card.id},
        ),
      ),
    );
  }
}
