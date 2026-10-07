import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/widgets/dialogs.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/cubit/board_cubit.dart';
import 'package:flowboard/features/boards/presentation/widgets/card_tile.dart';
import 'package:flowboard/features/boards/presentation/widgets/quick_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _BoardAction {
  addColumn,
  renameColumn,
  deleteColumn,
  renameBoard,
  deleteBoard,
}

/// Mobile board: one column per screen (PageView) with column tabs on top.
///
/// Long-press a card to drag it. Holding it near the left/right screen edge
/// pages to the neighbouring column; dropping inserts it at the indicator.
/// Dropping on a tab moves it to the end of that column.
class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  /// Width of the auto-paging zone at each screen edge.
  static const edgeZone = 48.0;

  /// How long a drag must stay in the edge zone before paging.
  static const edgeDelay = Duration(milliseconds: 600);

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final _pages = PageController();
  int _page = 0;
  Timer? _edgeTimer;
  int _edgeDirection = 0;
  bool _dragging = false;

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  int get _columnCount => context.read<BoardCubit>().state.columns.length;

  void _goTo(int page) {
    if (page < 0 || page >= _columnCount || !_pages.hasClients) return;
    unawaited(
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _onDragStarted() => setState(() => _dragging = true);

  void _onDragUpdate(Offset global) {
    final width = MediaQuery.sizeOf(context).width;
    final direction = global.dx < BoardPage.edgeZone
        ? -1
        : global.dx > width - BoardPage.edgeZone
        ? 1
        : 0;
    if (direction == _edgeDirection) return;
    _edgeDirection = direction;
    _edgeTimer?.cancel();
    if (direction != 0) {
      _edgeTimer = Timer.periodic(
        BoardPage.edgeDelay,
        (_) => _goTo(_page + _edgeDirection),
      );
    }
  }

  void _onDragEnd() {
    _edgeTimer?.cancel();
    _edgeDirection = 0;
    if (mounted) setState(() => _dragging = false);
  }

  Future<void> _moveCard(CardSummary card, String columnId, int index) async {
    _onDragEnd();
    await context.read<BoardCubit>().moveCard(card.id, columnId, index);
  }

  void _openCard(CardSummary card) {
    final params = GoRouterState.of(context).pathParameters;
    unawaited(
      context.pushNamed(
        AppRoutes.card,
        pathParameters: {...params, 'cardId': card.id},
      ),
    );
  }

  Future<void> _onAction(_BoardAction action, BoardState state) async {
    final l10n = context.l10n;
    final cubit = context.read<BoardCubit>();
    final column = state.columns.isEmpty
        ? null
        : state.columns[_page.clamp(0, state.columns.length - 1)].column;
    switch (action) {
      case _BoardAction.addColumn:
        final title = await showTextPrompt(
          context,
          title: l10n.boardAddColumn,
          label: l10n.columnTitleLabel,
          confirmLabel: l10n.commonCreate,
        );
        if (title == null) return;
        await cubit.addColumn(title);
        // Jump to the new column once it is rendered.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _goTo(_columnCount - 1),
        );
      case _BoardAction.renameColumn:
        if (column == null) return;
        final title = await showTextPrompt(
          context,
          title: l10n.columnRename,
          label: l10n.columnTitleLabel,
          confirmLabel: l10n.commonSave,
          initialValue: column.title,
        );
        if (title != null) await cubit.renameColumn(column.id, title);
      case _BoardAction.deleteColumn:
        if (column == null) return;
        final ok = await showConfirm(
          context,
          title: l10n.columnDeleteConfirm(column.title),
          confirmLabel: l10n.commonDelete,
        );
        if (ok) await cubit.deleteColumn(column.id);
      case _BoardAction.renameBoard:
        final title = await showTextPrompt(
          context,
          title: l10n.boardRename,
          label: l10n.boardTitleLabel,
          confirmLabel: l10n.commonSave,
          initialValue: state.content?.board.title ?? '',
        );
        if (title != null) await cubit.renameBoard(title);
      case _BoardAction.deleteBoard:
        final ok = await showConfirm(
          context,
          title: l10n.boardDeleteConfirm(state.content?.board.title ?? ''),
          confirmLabel: l10n.commonDelete,
        );
        if (!ok) return;
        await cubit.deleteBoard();
        if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BoardCubit, BoardState>(
      listenWhen: (prev, next) => prev.columns.length != next.columns.length,
      listener: (context, state) {
        if (_page >= state.columns.length && state.columns.isNotEmpty) {
          _goTo(state.columns.length - 1);
        }
      },
      builder: (context, state) {
        if (state.status == BoardStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == BoardStatus.notFound) {
          return Scaffold(
            appBar: AppBar(),
            body: MessageView(
              icon: Icons.delete_outline,
              title: l10n.boardNotFound,
            ),
          );
        }
        final columns = state.columns;
        final page = columns.isEmpty ? 0 : _page.clamp(0, columns.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: Text(state.content!.board.title),
            actions: [
              PopupMenuButton<_BoardAction>(
                tooltip: l10n.commonMoreActions,
                onSelected: (action) => _onAction(action, state),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _BoardAction.addColumn,
                    child: Text(l10n.boardAddColumn),
                  ),
                  if (columns.isNotEmpty) ...[
                    PopupMenuItem(
                      value: _BoardAction.renameColumn,
                      child: Text(l10n.columnRename),
                    ),
                    PopupMenuItem(
                      value: _BoardAction.deleteColumn,
                      child: Text(l10n.columnDelete),
                    ),
                  ],
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _BoardAction.renameBoard,
                    child: Text(l10n.boardRename),
                  ),
                  PopupMenuItem(
                    value: _BoardAction.deleteBoard,
                    child: Text(l10n.boardDelete),
                  ),
                ],
              ),
            ],
            bottom: columns.isEmpty
                ? null
                : _ColumnTabs(
                    columns: columns,
                    selected: page,
                    onSelect: _goTo,
                    onDropToColumn: (card, column) => _moveCard(
                      card,
                      column.column.id,
                      column.cards.length,
                    ),
                  ),
          ),
          body: columns.isEmpty
              ? MessageView(
                  icon: Icons.view_column_outlined,
                  title: l10n.boardNoColumnsTitle,
                  body: l10n.boardNoColumnsBody,
                  action: FilledButton.icon(
                    onPressed: () => _onAction(_BoardAction.addColumn, state),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.boardAddColumn),
                  ),
                )
              : PageView.builder(
                  controller: _pages,
                  // Paging is driven by the edge timer while dragging.
                  physics: _dragging
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: columns.length,
                  itemBuilder: (context, i) => _ColumnView(
                    key: ValueKey(columns[i].column.id),
                    column: columns[i],
                    onOpenCard: _openCard,
                    onDrop: (card, index) =>
                        _moveCard(card, columns[i].column.id, index),
                    onDragStarted: _onDragStarted,
                    onDragUpdate: _onDragUpdate,
                    onDragEnd: _onDragEnd,
                  ),
                ),
          floatingActionButton: columns.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    final columnId = columns[page].column.id;
                    unawaited(
                      QuickTaskSheet.show(
                        context,
                        (title) => context.read<BoardCubit>().createCard(
                          columnId,
                          title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTask),
                ),
        );
      },
    );
  }
}

class _ColumnTabs extends StatefulWidget implements PreferredSizeWidget {
  const _ColumnTabs({
    required this.columns,
    required this.selected,
    required this.onSelect,
    required this.onDropToColumn,
  });

  final List<ColumnWithCards> columns;
  final int selected;
  final ValueChanged<int> onSelect;
  final void Function(CardSummary card, ColumnWithCards column) onDropToColumn;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  State<_ColumnTabs> createState() => _ColumnTabsState();
}

class _ColumnTabsState extends State<_ColumnTabs> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_ColumnTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx =
            _keys[widget.columns[widget.selected].column.id]?.currentContext;
        if (ctx != null && ctx.mounted) {
          unawaited(
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: widget.preferredSize.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: widget.columns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final column = widget.columns[i];
          final key = _keys.putIfAbsent(column.column.id, GlobalKey.new);
          return DragTarget<DraggedCard>(
            onWillAcceptWithDetails: (d) =>
                d.data.card.columnId != column.column.id,
            onAcceptWithDetails: (d) =>
                widget.onDropToColumn(d.data.card, column),
            builder: (context, candidates, _) => Semantics(
              key: key,
              label: l10n.columnSemantics(
                column.column.title,
                column.cards.length,
              ),
              selected: i == widget.selected,
              button: true,
              excludeSemantics: true,
              child: ChoiceChip(
                selected: i == widget.selected || candidates.isNotEmpty,
                onSelected: (_) => widget.onSelect(i),
                showCheckmark: false,
                label: Text('${column.column.title}  ${column.cards.length}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColumnView extends StatefulWidget {
  const _ColumnView({
    required this.column,
    required this.onOpenCard,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    super.key,
  });

  final ColumnWithCards column;
  final ValueChanged<CardSummary> onOpenCard;
  final void Function(CardSummary card, int index) onDrop;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_ColumnView> createState() => _ColumnViewState();
}

/// Kept alive so a drag that started here survives paging away: a disposed
/// Draggable would never report onDragEnd.
class _ColumnViewState extends State<_ColumnView>
    with AutomaticKeepAliveClientMixin {
  final _cardKeys = <String, GlobalKey>{};

  @override
  bool get wantKeepAlive => true;

  /// Insertion index among the cards other than the dragged one.
  int? _hoverIndex;

  /// Index where a card dropped at [globalY] lands, ignoring [dragged].
  int _indexFor(double globalY, CardSummary dragged) {
    var index = 0;
    var seenVisible = false;
    for (final card in widget.column.cards) {
      if (card.id == dragged.id) continue;
      final box =
          _cardKeys[card.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        // Not laid out: above the viewport if nothing visible seen yet.
        if (seenVisible) break;
        index++;
        continue;
      }
      seenVisible = true;
      final middle = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
      if (globalY < middle) break;
      index++;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return DragTarget<DraggedCard>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        final index = _indexFor(details.offset.dy, details.data.card);
        if (index != _hoverIndex) setState(() => _hoverIndex = index);
      },
      onLeave: (_) => setState(() => _hoverIndex = null),
      onAcceptWithDetails: (details) {
        final index = _indexFor(details.offset.dy, details.data.card);
        setState(() => _hoverIndex = null);
        widget.onDrop(details.data.card, index);
      },
      builder: (context, candidates, _) {
        final cards = widget.column.cards;
        if (cards.isEmpty && candidates.isEmpty) {
          return MessageView(
            icon: Icons.inbox_outlined,
            title: l10n.columnEmpty,
            body: l10n.columnEmptyHint,
          );
        }
        final indicator = Container(
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
        final dragged = candidates.firstOrNull?.card;
        final children = <Widget>[];
        var otherIndex = 0;
        for (final card in cards) {
          final isDragged = card.id == dragged?.id;
          if (!isDragged && otherIndex == _hoverIndex) children.add(indicator);
          children.add(
            Padding(
              key: _cardKeys.putIfAbsent(card.id, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: 8),
              child: CardTile(
                card: card,
                onTap: () => widget.onOpenCard(card),
                onDragStarted: widget.onDragStarted,
                onDragUpdate: widget.onDragUpdate,
                onDragEnd: widget.onDragEnd,
              ),
            ),
          );
          if (!isDragged) otherIndex++;
        }
        if (_hoverIndex != null && _hoverIndex! >= otherIndex) {
          children.add(indicator);
        }
        return ListView(
          // Bottom padding keeps the last card above the FAB.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: children,
        );
      },
    );
  }
}
