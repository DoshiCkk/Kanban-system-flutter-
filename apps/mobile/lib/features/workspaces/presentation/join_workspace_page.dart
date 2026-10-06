import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/join_workspace_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/workspace_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class JoinWorkspacePage extends StatelessWidget {
  const JoinWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<JoinWorkspaceCubit, JoinWorkspaceState>(
      listenWhen: (prev, next) =>
          prev.status != next.status || prev.error != next.error,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == JoinStatus.joined) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.joinedSnack(state.joined!.name))),
          );
          context.goNamed(AppRoutes.home);
        } else if (state.status == JoinStatus.ready && state.error != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.apiError(state.error))),
          );
        }
      },
      builder: (context, state) {
        final preview = state.preview;
        final canJoin =
            preview != null &&
            !preview.alreadyMember &&
            state.status != JoinStatus.failure;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.joinTitle)),
          body: switch (state.status) {
            JoinStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            JoinStatus.failure => MessageView(
              icon: Icons.link_off,
              title: l10n.apiError(state.error),
              action: FilledButton.tonal(
                onPressed: () => context.goNamed(AppRoutes.home),
                child: Text(l10n.joinOpenWorkspaces),
              ),
            ),
            _ => MessageView(
              icon: Icons.groups_outlined,
              title: preview!.workspaceName,
              body: [
                l10n.joinInvitedTo,
                l10n.workspaceMemberCount(preview.memberCount),
                if (preview.alreadyMember) l10n.joinAlreadyMember,
              ].join('\n'),
              action: preview.alreadyMember
                  ? FilledButton.tonal(
                      onPressed: () => context.goNamed(AppRoutes.home),
                      child: Text(l10n.joinOpenWorkspaces),
                    )
                  : InitialAvatar(preview.workspaceName),
            ),
          },
          bottomNavigationBar: canJoin
              ? SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: state.status == JoinStatus.ready
                        ? context.read<JoinWorkspaceCubit>().accept
                        : null,
                    child: state.status == JoinStatus.joining
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.joinButton),
                  ),
                )
              : null,
        );
      },
    );
  }
}
