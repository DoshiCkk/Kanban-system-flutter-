import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Title-only task creation. Enter creates the task and keeps the sheet
/// open for the next one; swipe down to close.
class QuickTaskSheet extends StatefulWidget {
  const QuickTaskSheet({required this.onCreate, super.key});

  final Future<void> Function(String title) onCreate;

  static Future<void> show(
    BuildContext context,
    Future<void> Function(String title) onCreate,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickTaskSheet(onCreate: onCreate),
  );

  @override
  State<QuickTaskSheet> createState() => _QuickTaskSheetState();
}

class _QuickTaskSheetState extends State<QuickTaskSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    await widget.onCreate(title);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quickTaskTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.quickTaskHint,
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: l10n.commonCreate,
                icon: const Icon(Icons.send),
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
