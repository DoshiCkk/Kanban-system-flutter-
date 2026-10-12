import 'dart:async';

import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/sync_cubit.dart';
import 'package:flowboard/core/widgets/dialogs.dart';
import 'package:flowboard/features/auth/domain/user.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flowboard/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _LogoutChoice { sync, anyway }

/// Who I am: name (editable), e-mail, sign-up date, my numbers, settings
/// and sign-out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _editName(BuildContext context, User user) async {
    final l10n = context.l10n;
    final cubit = context.read<ProfileCubit>();
    final name = await showTextPrompt(
      context,
      title: l10n.profileEditName,
      label: l10n.authNameLabel,
      confirmLabel: l10n.commonSave,
      initialValue: user.name,
    );
    if (name != null && name != user.name) await cubit.rename(name);
  }

  /// Warns when the outbox still holds changes (docs/sync.md §8).
  Future<void> _logout(BuildContext context) async {
    final l10n = context.l10n;
    final auth = context.read<AuthCubit>();
    final sync = context.read<SyncCubit>();
    final pending = sync.state.pending;
    if (pending > 0) {
      final choice = await showDialog<_LogoutChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.logoutUnsyncedTitle(pending)),
          content: Text(l10n.logoutUnsyncedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LogoutChoice.anyway),
              child: Text(l10n.logoutAnyway),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LogoutChoice.sync),
              child: Text(l10n.logoutSyncAndSignOut),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      if (choice == _LogoutChoice.sync && !await sync.syncNow()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.logoutSyncFailed)));
        }
        return;
      }
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select<AuthCubit, User?>((c) => c.state.user);
    if (user == null) return const SizedBox.shrink();
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.rename != b.rename,
      listener: (context, state) {
        final message = switch (state.rename) {
          RenameStatus.saved => l10n.profileNameSaved,
          RenameStatus.failed => l10n.apiError(state.error),
          RenameStatus.idle || RenameStatus.saving => null,
        };
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.navProfile)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Header(user: user),
            const SizedBox(height: 16),
            const _Stats(),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.profileEditName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(_editName(context, user)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.profileSettings),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const ValueKey('logout'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => unawaited(_logout(context)),
              icon: const Icon(Icons.logout),
              label: Text(l10n.settingsLogout),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = user.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    final since = user.createdAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      children: [
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.name,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (since != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.profileMemberSince(
              DateFormat.yMMMMd(locale).format(since.toLocal()),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaces = context.select<ProfileCubit, int?>(
      (c) => c.state.workspaceCount,
    );
    final tasks = context.watch<MyTasksCubit>().state;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: workspaces?.toString() ?? '—',
            label: l10n.profileStatWorkspaces,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            value: '${tasks.active}',
            label: l10n.profileStatActive,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            value: '${tasks.count(TaskGroup.done)}',
            label: l10n.profileStatDone,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: MergeSemantics(
          child: Column(
            children: [
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
