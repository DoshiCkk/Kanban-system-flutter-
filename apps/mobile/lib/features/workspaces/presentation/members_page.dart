import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/members_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/workspace_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _MemberAction { makeAdmin, makeMember, remove }

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final myId = context.select<AuthCubit, String?>((c) => c.state.user?.id);

    return BlocBuilder<MembersCubit, MembersState>(
      builder: (context, state) {
        final workspace = state.workspace;
        final myRole = workspace?.role;
        return Scaffold(
          appBar: AppBar(
            title: Text(workspace?.name ?? l10n.membersTitle),
            actions: [
              if (myRole != null && myRole != WorkspaceRole.owner)
                IconButton(
                  tooltip: l10n.memberLeave,
                  icon: const Icon(Icons.logout),
                  onPressed: () => _leave(context, workspace!, myId!),
                ),
            ],
          ),
          body: _body(context, state, myId),
          bottomNavigationBar: myRole != null && myRole.canInvite
              ? SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => _invite(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l10n.membersInvite),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _body(BuildContext context, MembersState state, String? myId) {
    final l10n = context.l10n;
    final cubit = context.read<MembersCubit>();
    if (state.members.isEmpty) {
      if (state.status == LoadStatus.failure) {
        return MessageView(
          icon: Icons.cloud_off_outlined,
          title: l10n.apiError(state.error),
          action: FilledButton.tonal(
            onPressed: cubit.load,
            child: Text(l10n.commonRetry),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final myRole = state.workspace?.role ?? WorkspaceRole.member;
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.workspaceMemberCount(state.members.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final member in state.members)
            _MemberTile(
              member: member,
              isMe: member.user.id == myId,
              actions: member.user.id == myId
                  ? const []
                  : _actionsFor(myRole, member.role),
              onAction: (action) => _onAction(context, member, action),
            ),
        ],
      ),
    );
  }

  List<_MemberAction> _actionsFor(WorkspaceRole me, WorkspaceRole target) => [
    if (me.canManageRoles && target == WorkspaceRole.member)
      _MemberAction.makeAdmin,
    if (me.canManageRoles && target == WorkspaceRole.admin)
      _MemberAction.makeMember,
    if (me.canRemove(target)) _MemberAction.remove,
  ];

  Future<void> _onAction(
    BuildContext context,
    Member member,
    _MemberAction action,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<MembersCubit>();
    if (action == _MemberAction.remove) {
      final ok = await _confirm(
        context,
        l10n.memberRemoveConfirm(member.user.name),
        l10n.commonRemove,
      );
      if (!ok || !context.mounted) return;
    }
    await _guard(context, () async {
      switch (action) {
        case _MemberAction.makeAdmin:
          await cubit.changeRole(member.user.id, WorkspaceRole.admin);
        case _MemberAction.makeMember:
          await cubit.changeRole(member.user.id, WorkspaceRole.member);
        case _MemberAction.remove:
          await cubit.remove(member.user.id);
      }
    });
  }

  Future<void> _leave(
    BuildContext context,
    Workspace workspace,
    String myId,
  ) async {
    final l10n = context.l10n;
    final ok = await _confirm(
      context,
      l10n.memberLeaveConfirm(workspace.name),
      l10n.commonLeave,
    );
    if (!ok || !context.mounted) return;
    final left = await _guard(
      context,
      () => context.read<MembersCubit>().remove(myId),
    );
    if (left && context.mounted) context.pop();
  }

  Future<void> _invite(BuildContext context) async {
    final cubit = context.read<MembersCubit>();
    Invite? invite;
    await _guard(context, () async => invite = await cubit.createInvite());
    if (invite == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _InviteSheet(invite: invite!),
    );
  }

  /// Runs [action]; on failure shows a snackbar. Returns success.
  Future<bool> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.apiError(e.code))),
        );
      }
      return false;
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String confirmLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.actions,
    required this.onAction,
  });

  final Member member;
  final bool isMe;
  final List<_MemberAction> actions;
  final ValueChanged<_MemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = isMe ? l10n.memberYou(member.user.name) : member.user.name;
    return ListTile(
      leading: InitialAvatar(member.user.name),
      title: Text(name),
      subtitle: Text(member.user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.role(member.role),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<_MemberAction>(
              tooltip: l10n.memberActions,
              onSelected: onAction,
              itemBuilder: (_) => [
                for (final action in actions)
                  PopupMenuItem(
                    value: action,
                    child: Text(switch (action) {
                      _MemberAction.makeAdmin => l10n.memberMakeAdmin,
                      _MemberAction.makeMember => l10n.memberMakeMember,
                      _MemberAction.remove => l10n.memberRemove,
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final link = invite.link.toString();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.inviteSheetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.inviteSheetBody(invite.expiresAt.toLocal())),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(link, style: theme.textTheme.bodySmall),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.commonCopied)));
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.commonCopy),
            ),
          ],
        ),
      ),
    );
  }
}
