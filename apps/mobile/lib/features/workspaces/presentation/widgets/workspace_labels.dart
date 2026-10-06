import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter/material.dart';

extension WorkspaceRoleLabel on AppLocalizations {
  String role(WorkspaceRole role) => switch (role) {
    WorkspaceRole.owner => roleOwner,
    WorkspaceRole.admin => roleAdmin,
    WorkspaceRole.member => roleMember,
  };
}

/// Circle with the first letter of [name]; decorative for screen readers.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Text(initial),
      ),
    );
  }
}
