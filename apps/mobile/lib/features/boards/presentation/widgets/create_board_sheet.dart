import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flowboard/features/boards/presentation/widgets/board_labels.dart';
import 'package:flutter/material.dart';

typedef CreateBoard =
    Future<Board> Function({
      required String title,
      required BoardTemplate template,
      required List<String> columnTitles,
    });

/// Title + template picker. Pops with the created [Board].
class CreateBoardSheet extends StatefulWidget {
  const CreateBoardSheet({required this.onCreate, super.key});

  final CreateBoard onCreate;

  static Future<Board?> show(BuildContext context, CreateBoard onCreate) =>
      showModalBottomSheet<Board>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CreateBoardSheet(onCreate: onCreate),
      );

  @override
  State<CreateBoardSheet> createState() => _CreateBoardSheetState();
}

class _CreateBoardSheetState extends State<CreateBoardSheet> {
  final _controller = TextEditingController();
  BoardTemplate _template = BoardTemplate.basic;
  bool _submitting = false;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _submitting = true);
    final board = await widget.onCreate(
      title: title,
      template: _template,
      columnTitles: context.l10n.templateColumns(_template),
    );
    if (mounted) Navigator.of(context).pop(board);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.boardsCreate, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.boardTitleLabel,
                border: const OutlineInputBorder(),
                errorText: _showError
                    ? l10n.validationWorkspaceNameRequired
                    : null,
              ),
            ),
            Text(l10n.boardTemplateLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RadioGroup<BoardTemplate>(
              groupValue: _template,
              onChanged: (t) {
                if (t != null) setState(() => _template = t);
              },
              child: Column(
                children: [
                  for (final template in BoardTemplate.values)
                    RadioListTile<BoardTemplate>(
                      value: template,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.templateName(template)),
                      subtitle: Text(
                        template == BoardTemplate.empty
                            ? l10n.templateEmptyColumns
                            : l10n.templateColumns(template).join(' · '),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(l10n.commonCreate),
            ),
          ],
        ),
      ),
    );
  }
}
