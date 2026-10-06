import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';

/// Bottom sheet with a single name field. Enter submits.
/// Pops with the created [Workspace].
class CreateWorkspaceSheet extends StatefulWidget {
  const CreateWorkspaceSheet({required this.onCreate, super.key});

  final Future<Workspace> Function(String name) onCreate;

  static Future<Workspace?> show(
    BuildContext context,
    Future<Workspace> Function(String name) onCreate,
  ) => showModalBottomSheet<Workspace>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CreateWorkspaceSheet(onCreate: onCreate),
  );

  @override
  State<CreateWorkspaceSheet> createState() => _CreateWorkspaceSheetState();
}

class _CreateWorkspaceSheetState extends State<CreateWorkspaceSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.validationWorkspaceNameRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final workspace = await widget.onCreate(name);
      if (mounted) Navigator.of(context).pop(workspace);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = l10n.apiError(e.code);
        });
      }
    }
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
            l10n.workspacesCreate,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.workspaceNameLabel,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonCreate),
          ),
        ],
      ),
    );
  }
}
