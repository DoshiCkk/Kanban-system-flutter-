import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/widgets/board_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

/// Payload of a card drag.
class DraggedCard {
  const DraggedCard(this.card);

  final CardSummary card;
}

/// A card in a column. Tap opens it, long press starts a drag. Screen
/// reader users move it with [moves] instead (custom semantics actions).
class CardTile extends StatelessWidget {
  const CardTile({
    required this.card,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.moves = const {},
    super.key,
  });

  final CardSummary card;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  /// Action label -> move, e.g. "Move to the Done column".
  final Map<String, VoidCallback> moves;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final body = CardBody(card: card);
    return LongPressDraggable<DraggedCard>(
      data: DraggedCard(card),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        // Keep the card under the finger.
        offset: Offset(-width / 2, -36),
        child: SizedBox(
          width: width,
          child: Material(
            color: Colors.transparent,
            child: Transform.rotate(
              angle: -0.03,
              child: CardBody(card: card, elevated: true),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: body),
      onDragStarted: onDragStarted,
      onDragUpdate: (details) => onDragUpdate(details.globalPosition),
      onDragEnd: (_) => onDragEnd(),
      onDraggableCanceled: (_, _) => onDragEnd(),
      child: CardBody(
        card: card,
        onTap: onTap,
        semanticsHint: context.l10n.cardDragHint,
        semanticsActions: {
          for (final MapEntry(key: label, value: move) in moves.entries)
            CustomSemanticsAction(label: label): move,
        },
      ),
    );
  }
}

class CardBody extends StatelessWidget {
  const CardBody({
    required this.card,
    this.onTap,
    this.elevated = false,
    this.semanticsHint,
    this.semanticsActions = const {},
    super.key,
  });

  final CardSummary card;
  final VoidCallback? onTap;
  final bool elevated;

  /// Added to the card's own semantics node (the Card is a container, so
  /// an annotation outside it would land on a separate node).
  final String? semanticsHint;
  final Map<CustomSemanticsAction, VoidCallback> semanticsActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final due = card.dueDate;
    final overdue =
        due != null && due.isBefore(DateUtils.dateOnly(DateTime.now()));
    final dueText = due == null
        ? ''
        : DateFormat.MMMd(locale).format(due.toLocal());
    final meta = <Widget>[
      if (card.priority != CardPriority.medium)
        _Meta(
          icon: priorityIcon(card.priority),
          text: l10n.priority(card.priority),
          color: priorityColor(card.priority, scheme),
        ),
      if (due != null)
        _Meta(
          icon: Icons.event_outlined,
          text: dueText,
          semanticsLabel: overdue
              ? l10n.cardOverdueSemantics(dueText)
              : l10n.cardDueSemantics(dueText),
          color: overdue ? scheme.error : null,
        ),
      if (card.checklistTotal > 0)
        _Meta(
          icon: Icons.checklist,
          text: l10n.cardChecklistBadge(
            card.checklistDone,
            card.checklistTotal,
          ),
          semanticsLabel: l10n.cardChecklistSemantics(
            card.checklistDone,
            card.checklistTotal,
          ),
          color: card.checklistDone == card.checklistTotal
              ? successColor(scheme)
              : null,
        ),
      if (card.assigneeId != null)
        _Meta(
          icon: Icons.person_outline,
          text: '',
          semanticsLabel: l10n.cardHasAssignee,
        ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: elevated ? 8 : 1,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        hint: semanticsHint,
        customSemanticsActions: semanticsActions,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.labels.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final label in card.labels.take(3))
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: labelColor(label, scheme),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(card.title, style: theme.textTheme.bodyLarge),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 4, children: meta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.semanticsLabel,
    this.color,
  });

  final IconData icon;
  final String text;

  /// Spoken instead of [text] when the short form is ambiguous.
  final String? semanticsLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(text, style: style),
        ],
      ],
    );
    final label = semanticsLabel;
    return label == null
        ? row
        : Semantics(label: label, excludeSemantics: true, child: row);
  }
}
