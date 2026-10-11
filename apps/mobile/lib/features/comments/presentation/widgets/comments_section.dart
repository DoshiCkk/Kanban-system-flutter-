import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/widgets/dialogs.dart';
import 'package:flowboard/features/comments/domain/comment.dart';
import 'package:flowboard/features/comments/domain/mentions.dart';
import 'package:flowboard/features/comments/presentation/cubit/comments_cubit.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Card comments with an `@mention` composer. [members] name authors and
/// mentions; `null` = member list unavailable (offline, nothing cached).
class CommentsSection extends StatelessWidget {
  const CommentsSection({required this.members, super.key});

  final List<MemberUser>? members;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final comments = context.select<CommentsCubit, List<Comment>>(
      (c) => c.state.comments,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l10n.commentsTitle, style: theme.textTheme.titleSmall),
        ),
        if (comments.isEmpty)
          Text(
            l10n.commentsEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final comment in comments)
          _CommentTile(
            key: ValueKey(comment.id),
            comment: comment,
            members: members,
          ),
        const SizedBox(height: 8),
        _Composer(members: members),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = (name ?? '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      child: initials.isEmpty
          ? const Icon(Icons.person_outline, size: 20)
          : Text(initials, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

enum _CommentAction { edit, delete }

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.members,
    super.key,
  });

  final Comment comment;
  final List<MemberUser>? members;

  Future<void> _onAction(BuildContext context, _CommentAction action) async {
    final cubit = context.read<CommentsCubit>();
    switch (action) {
      case _CommentAction.edit:
        cubit.startEditing(comment);
      case _CommentAction.delete:
        final l10n = context.l10n;
        final confirmed = await showConfirm(
          context,
          title: l10n.commentDeleteConfirm,
          confirmLabel: l10n.commonDelete,
        );
        if (confirmed) await cubit.delete(comment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final author = members?.where((m) => m.id == comment.authorId).firstOrNull;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.MMMd(
      locale,
    ).add_Hm().format(comment.createdAt.toLocal());
    final mine = context.read<CommentsCubit>().isMine(comment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: author?.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author?.name ?? l10n.commentUnknownAuthor,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (comment.pending)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: l10n.commentPending,
                          child: Icon(Icons.schedule, size: 16, color: muted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                _MentionText(comment: comment, members: members),
              ],
            ),
          ),
          if (mine)
            PopupMenuButton<_CommentAction>(
              tooltip: l10n.commentActions,
              onSelected: (a) => _onAction(context, a),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _CommentAction.edit,
                  child: Text(l10n.commentEdit),
                ),
                PopupMenuItem(
                  value: _CommentAction.delete,
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Comment text with the `@Name` of each mentioned member highlighted.
class _MentionText extends StatelessWidget {
  const _MentionText({required this.comment, required this.members});

  final Comment comment;
  final List<MemberUser>? members;

  @override
  Widget build(BuildContext context) {
    final text = comment.text;
    final mentioned = (members ?? const <MemberUser>[]).where(
      (m) => comment.mentions.contains(m.id),
    );
    final style = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final match in findMentions(text, mentioned)) {
      spans
        ..add(TextSpan(text: text.substring(at, match.start)))
        ..add(
          TextSpan(text: text.substring(match.start, match.end), style: style),
        );
      at = match.end;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(children: spans));
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.members});

  final List<MemberUser>? members;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  MentionQuery? _query;
  List<MemberUser> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateSuggestions);
  }

  @override
  void didUpdateWidget(_Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members) _updateSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _updateSuggestions() {
    final members = widget.members;
    final selection = _controller.selection;
    MentionQuery? query;
    var suggestions = const <MemberUser>[];
    if (members != null && selection.isValid && selection.isCollapsed) {
      query = mentionQueryAt(_controller.text, selection.baseOffset);
      if (query != null) {
        suggestions = mentionSuggestions(query.query, members);
      }
    }
    if (query?.start != _query?.start ||
        !listEquals(suggestions, _suggestions)) {
      setState(() {
        _query = query;
        _suggestions = suggestions;
      });
    }
  }

  void _pick(MemberUser user) {
    final query = _query;
    if (query == null) return;
    final result = insertMention(
      _controller.text,
      query,
      _controller.selection.baseOffset,
      user.name,
    );
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final sent = await context.read<CommentsCubit>().submit(
      _controller.text,
      widget.members,
    );
    if (sent) _controller.clear();
  }

  void _cancelEditing() {
    context.read<CommentsCubit>().cancelEditing();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = context.select<CommentsCubit, Comment?>(
      (c) => c.state.editing,
    );
    return BlocListener<CommentsCubit, CommentsState>(
      listenWhen: (a, b) => a.editing?.id != b.editing?.id,
      listener: (context, state) {
        final text = state.editing?.text;
        if (text == null) return;
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _focus.requestFocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (editing != null)
            Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.commentEditing)),
                IconButton(
                  tooltip: l10n.commonCancel,
                  icon: const Icon(Icons.close),
                  onPressed: _cancelEditing,
                ),
              ],
            ),
          if (_suggestions.isNotEmpty)
            Semantics(
              label: l10n.commentMentionSuggestions,
              container: true,
              child: Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: Column(
                  children: [
                    for (final user in _suggestions)
                      ListTile(
                        key: ValueKey('mention-${user.id}'),
                        leading: _Avatar(name: user.name),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        onTap: () => _pick(user),
                      ),
                  ],
                ),
              ),
            ),
          TextField(
            key: const ValueKey('comment-input'),
            controller: _controller,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.commentHint,
              counterText: '',
              suffixIcon: IconButton(
                key: const ValueKey('comment-send'),
                tooltip: editing == null ? l10n.commentSend : l10n.commonSave,
                icon: Icon(editing == null ? Icons.send : Icons.check),
                onPressed: () => unawaited(_submit()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
