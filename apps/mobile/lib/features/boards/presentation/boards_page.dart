import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/sync_indicator.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/cubit/boards_cubit.dart';
import 'package:flowboard/features/boards/presentation/widgets/create_board_sheet.dart';
import 'package:flowboard/features/workspaces/presentation/widgets/workspace_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BoardsPage extends StatelessWidget {
  const BoardsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<BoardsCubit>();
    final board = await CreateBoardSheet.show(context, cubit.create);
    if (board != null && context.mounted) _open(context, board);
  }

  void _open(BuildContext context, Board board) => context.pushNamed(
    AppRoutes.board,
    pathParameters: {'workspaceId': board.workspaceId, 'boardId': board.id},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<BoardsCubit, BoardsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.workspace?.name ?? l10n.boardsTitle),
            actions: [
              const SyncIndicator(),
              IconButton(
                tooltip: l10n.boardMembers,
                icon: const Icon(Icons.group_outlined),
                onPressed: () => context.pushNamed(
                  AppRoutes.members,
                  pathParameters: {
                    'workspaceId': context.read<BoardsCubit>().workspaceId,
                  },
                ),
              ),
            ],
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.boards.isEmpty
              ? MessageView(
                  icon: Icons.view_kanban_outlined,
                  title: l10n.boardsEmptyTitle,
                  body: l10n.boardsEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: state.boards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final board = state.boards[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: InitialAvatar(board.title),
                        title: Text(board.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(context, board),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.boardsCreate),
          ),
        );
      },
    );
  }
}
