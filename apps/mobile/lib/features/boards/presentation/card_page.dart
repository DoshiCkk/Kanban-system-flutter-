import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/widgets/dialogs.dart';
import 'package:flowboard/core/widgets/message_view.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/cubit/card_cubit.dart';
import 'package:flowboard/features/boards/presentation/widgets/board_labels.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _CardAction { delete }

/// Card details. Every edit is saved locally right away; the main action
/// ("move to the next column") sits at the bottom within thumb reach.
class CardPage extends StatelessWidget {
  const CardPage({super.key});

  Future<void> _onAction(BuildContext context, _CardAction action) async {
    final l10n = context.l10n;
    final cubit = context.read<CardCubit>();
    switch (action) {
      case _CardAction.delete:
        final confirmed = await showConfirm(
          context,
          title: l10n.cardDeleteConfirm,
          confirmLabel: l10n.commonDelete,
        );
        if (!confirmed || !context.mounted) return;
        await cubit.delete();
        if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CardCubit, CardState>(
      builder: (context, state) {
        final card = state.card;
        if (state.status == CardStatus.loading) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == CardStatus.notFound || card == null) {
          return Scaffold(
            appBar: AppBar(),
            body: MessageView(
              icon: Icons.delete_outline,
              title: l10n.cardNotFound,
            ),
          );
        }
        final next = card.nextColumn;
        return Scaffold(
          appBar: AppBar(
            title: Text(card.column?.title ?? ''),
            actions: [
              PopupMenuButton<_CardAction>(
                tooltip: l10n.commonMoreActions,
                onSelected: (a) => _onAction(context, a),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text(l10n.cardDelete),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SavedTextField(
                key: const ValueKey('card-title'),
                value: card.title,
                label: l10n.cardTitleLabel,
                maxLength: 200,
                style: Theme.of(context).textTheme.titleLarge,
                onSave: context.read<CardCubit>().rename,
              ),
              const SizedBox(height: 8),
              _StatusTile(card: card),
              _AssigneeTile(state: state),
              _DueDateTile(card: card),
              const SizedBox(height: 8),
              _Section(title: l10n.cardPriority),
              _PrioritySelector(card: card),
              const SizedBox(height: 16),
              _Section(title: l10n.cardLabels),
              _Labels(card: card),
              const SizedBox(height: 16),
              _Section(title: l10n.cardDescription),
              _SavedTextField(
                key: const ValueKey('card-description'),
                value: card.description,
                hint: l10n.cardDescriptionHint,
                maxLength: 5000,
                multiline: true,
                allowEmpty: true,
                onSave: (text) => context.read<CardCubit>().update(
                  CardPatch(description: text),
                ),
              ),
              const SizedBox(height: 16),
              _Checklist(card: card),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: next == null
                    ? null
                    : context.read<CardCubit>().moveToNextColumn,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  next == null
                      ? l10n.cardInLastColumn
                      : l10n.cardMoveNext(next.title),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Text field that saves when it loses focus (or on submit for single-line
/// fields) and follows external changes while not being edited.
class _SavedTextField extends StatefulWidget {
  const _SavedTextField({
    required this.value,
    required this.onSave,
    required this.maxLength,
    this.label,
    this.hint,
    this.style,
    this.multiline = false,
    this.allowEmpty = false,
    super.key,
  });

  final String value;
  final Future<void> Function(String text) onSave;
  final int maxLength;
  final String? label;
  final String? hint;
  final TextStyle? style;
  final bool multiline;
  final bool allowEmpty;

  @override
  State<_SavedTextField> createState() => _SavedTextFieldState();
}

class _SavedTextFieldState extends State<_SavedTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_save());
    });
  }

  @override
  void didUpdateWidget(_SavedTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text == widget.value) return;
    if (text.isEmpty && !widget.allowEmpty) {
      _controller.text = widget.value;
      return;
    }
    await widget.onSave(text);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    style: widget.style,
    maxLength: widget.maxLength,
    minLines: widget.multiline ? 3 : 1,
    maxLines: widget.multiline ? 12 : 1,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: widget.multiline
        ? TextInputAction.newline
        : TextInputAction.done,
    onSubmitted: widget.multiline ? null : (_) => _focus.unfocus(),
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      border: const OutlineInputBorder(),
      counterText: '',
    ),
  );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.card});

  final CardDetails card;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<CardCubit>();
    final columnId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final column in card.columns)
              ListTile(
                title: Text(column.title),
                trailing: column.id == card.columnId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(column.id),
              ),
          ],
        ),
      ),
    );
    if (columnId != null) await cubit.moveToColumn(columnId);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.view_column_outlined),
    title: Text(context.l10n.cardStatus),
    subtitle: Text(card.column?.title ?? ''),
    trailing: const Icon(Icons.expand_more),
    onTap: () => _pick(context),
  );
}

class _AssigneeTile extends StatelessWidget {
  const _AssigneeTile({required this.state});

  final CardState state;

  Future<void> _pick(BuildContext context, List<Member> members) async {
    final l10n = context.l10n;
    final cubit = context.read<CardCubit>();
    final current = state.card?.assigneeId;
    // Empty string = "unassigned"; null = sheet dismissed.
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: Text(l10n.cardUnassigned),
              trailing: current == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
            for (final m in members)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(m.user.name),
                subtitle: Text(m.user.email),
                trailing: m.user.id == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(m.user.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == (current ?? '')) return;
    await cubit.update(
      picked.isEmpty
          ? const CardPatch(clearAssignee: true)
          : CardPatch(assigneeId: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = state.members;
    final assigneeId = state.card?.assigneeId;
    final subtitle = [
      if (assigneeId == null)
        l10n.cardUnassigned
      else if (state.assignee case final m?)
        m.user.name,
      if (members == null || (assigneeId != null && state.assignee == null))
        l10n.cardMembersUnavailable,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(l10n.cardAssignee),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.expand_more),
      enabled: members != null,
      onTap: members == null ? null : () => _pick(context, members),
    );
  }
}

class _DueDateTile extends StatelessWidget {
  const _DueDateTile({required this.card});

  final CardDetails card;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<CardCubit>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: card.dueDate?.toLocal() ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) await cubit.update(CardPatch(dueDate: picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = card.dueDate;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(l10n.cardDueDate),
      subtitle: Text(
        due == null
            ? l10n.cardNoDueDate
            : DateFormat.yMMMd(locale).format(due.toLocal()),
      ),
      trailing: due == null
          ? null
          : IconButton(
              tooltip: l10n.cardClearDueDate,
              icon: const Icon(Icons.close),
              onPressed: () => context.read<CardCubit>().update(
                const CardPatch(clearDueDate: true),
              ),
            ),
      onTap: () => _pick(context),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.card});

  final CardDetails card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<CardPriority>(
      showSelectedIcon: false,
      segments: [
        for (final p in CardPriority.values)
          ButtonSegment(
            value: p,
            icon: Icon(priorityIcon(p)),
            label: Text(l10n.priority(p)),
          ),
      ],
      selected: {card.priority},
      onSelectionChanged: (s) =>
          context.read<CardCubit>().update(CardPatch(priority: s.first)),
    );
  }
}

class _Labels extends StatelessWidget {
  const _Labels({required this.card});

  final CardDetails card;

  Future<void> _add(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<CardCubit>();
    final label = await showTextPrompt(
      context,
      title: l10n.cardAddLabel,
      label: l10n.cardLabelHint,
      confirmLabel: l10n.commonCreate,
      maxLength: 30,
    );
    if (label != null) await cubit.addLabel(label);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in card.labels)
          InputChip(
            label: Text(label),
            backgroundColor: labelColor(label, scheme),
            deleteButtonTooltipMessage: l10n.cardRemoveLabel(label),
            onDeleted: () => context.read<CardCubit>().removeLabel(label),
          ),
        ActionChip(
          avatar: const Icon(Icons.add),
          label: Text(l10n.cardAddLabel),
          onPressed: () => _add(context),
        ),
      ],
    );
  }
}

class _Checklist extends StatefulWidget {
  const _Checklist({required this.card});

  final CardDetails card;

  @override
  State<_Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<_Checklist> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await context.read<CardCubit>().addChecklistItem(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = widget.card.checklist;
    final done = items.where((i) => i.done).length;
    final cubit = context.read<CardCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Section(title: l10n.cardChecklist)),
            if (items.isNotEmpty)
              Text(l10n.cardChecklistBadge(done, items.length)),
          ],
        ),
        if (items.isNotEmpty) ...[
          LinearProgressIndicator(value: done / items.length),
          const SizedBox(height: 4),
        ],
        for (final item in items)
          CheckboxListTile(
            key: ValueKey(item.id),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: item.done,
            onChanged: (_) => cubit.toggleChecklistItem(item),
            title: Text(
              item.text,
              style: item.done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            secondary: IconButton(
              tooltip: l10n.checklistDeleteItem,
              icon: const Icon(Icons.close),
              onPressed: () => cubit.deleteChecklistItem(item.id),
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            hintText: l10n.checklistAddHint,
            prefixIcon: const Icon(Icons.add),
            counterText: '',
          ),
        ),
      ],
    );
  }
}
