import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/create_workspace_sheet.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/join_link_dialog.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/workspace_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        title: Text(l10n.workspacesTitle),
        actions: [
          IconButton(
            tooltip: l10n.workspacesJoin,
            icon: const Icon(Icons.add_link),
            onPressed: () => _join(context),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: BlocBuilder<WorkspacesCubit, WorkspacesState>(
        builder: (context, state) {
          final cubit = context.read<WorkspacesCubit>();
          if (state.workspaces.isEmpty) {
            return switch (state.status) {
              LoadStatus.initial || LoadStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
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
            };
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView.separated(
              // Leave room for the FAB.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: state.workspaces.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _WorkspaceTile(workspace: state.workspaces[i]),
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
