import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/sync_indicator.dart';
import 'package:flowboard/core/widgets/brand.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/core/widgets/skeleton.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flowboard/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/create_workspace_sheet.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/join_link_dialog.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/workspace_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WorkspacesPage extends StatelessWidget {
  const WorkspacesPage({super.key});

  Future<void> _join(BuildContext context) async {
    final token = await JoinLinkDialog.show(context);
    if (token == null || !context.mounted) return;
    await context.pushNamed(AppRoutes.join, pathParameters: {'token': token});
    if (context.mounted) await context.read<WorkspacesCubit>().load();
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<WorkspacesCubit>();
    await CreateWorkspaceSheet.show(context, cubit.create);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            ExcludeSemantics(child: BrandLogo(size: 32)),
            SizedBox(width: 12),
            Flexible(child: Text(appName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          const SyncIndicator(),
          IconButton(
            tooltip: l10n.workspacesJoin,
            icon: const Icon(Icons.add_link),
            onPressed: () => _join(context),
          ),
        ],
      ),
      body: BlocBuilder<WorkspacesCubit, WorkspacesState>(
        builder: (context, state) {
          final cubit = context.read<WorkspacesCubit>();
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Leave room for the FAB.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const _Greeting(),
                const SizedBox(height: 16),
                const _TaskSummary(),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.workspacesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                if (state.workspaces.isEmpty)
                  switch (state.status) {
                    LoadStatus.initial ||
                    LoadStatus.loading => const SkeletonTiles(count: 2),
                    LoadStatus.failure => MessageView(
                      icon: Icons.cloud_off_outlined,
                      title: l10n.apiError(state.error),
                      action: FilledButton.tonal(
                        onPressed: cubit.load,
                        child: Text(l10n.commonRetry),
                      ),
                    ),
                    LoadStatus.success => MessageView(
                      icon: Icons.groups_outlined,
                      title: l10n.workspacesEmptyTitle,
                      body: l10n.workspacesEmptyBody,
                      action: OutlinedButton.icon(
                        onPressed: () => _join(context),
                        icon: const Icon(Icons.add_link),
                        label: Text(l10n.workspacesJoin),
                      ),
                    ),
                  }
                else
                  for (final workspace in state.workspaces)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WorkspaceTile(workspace: workspace),
                    ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.workspacesCreate),
      ),
    );
  }
}

/// "Hello, Aigerim!" and today's date.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = context.select<AuthCubit, String>(
      (c) => c.state.user?.name ?? '',
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = DateFormat.MMMMEEEEd(locale).format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.homeGreeting(name),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // Capitalized: ru/kk weekday names are lowercase.
          today.isEmpty ? today : today[0].toUpperCase() + today.substring(1),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// My tasks at a glance; each number opens the My tasks tab.
class _TaskSummary extends StatelessWidget {
  const _TaskSummary();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tasks = context.watch<MyTasksCubit>().state;
    final overdue = tasks.count(TaskGroup.overdue);
    void open() => context.goNamed(AppRoutes.myTasks);
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            key: const ValueKey('summary-overdue'),
            value: overdue,
            label: l10n.homeSummaryOverdue,
            icon: Icons.warning_amber_rounded,
            color: overdue > 0 ? scheme.error : null,
            onTap: open,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            key: const ValueKey('summary-today'),
            value: tasks.count(TaskGroup.today),
            label: l10n.homeSummaryToday,
            icon: Icons.today_outlined,
            onTap: open,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            key: const ValueKey('summary-active'),
            value: tasks.active,
            label: l10n.homeSummaryActive,
            icon: Icons.task_alt,
            onTap: open,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    super.key,
  });

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color ?? theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: InitialAvatar(workspace.name),
        title: Text(workspace.name),
        subtitle: Text(
          '${l10n.role(workspace.role)} · '
          '${l10n.workspaceMemberCount(workspace.memberCount)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await context.pushNamed(
            AppRoutes.boards,
            pathParameters: {'workspaceId': workspace.id},
          );
          if (context.mounted) await context.read<WorkspacesCubit>().load();
        },
      ),
    );
  }
}
