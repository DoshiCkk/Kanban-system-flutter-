import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/theme/app_colors.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter/material.dart';

extension BoardL10n on AppLocalizations {
  String templateName(BoardTemplate t) => switch (t) {
    BoardTemplate.basic => templateBasic,
    BoardTemplate.development => templateDevelopment,
    BoardTemplate.empty => templateEmpty,
  };

  /// Column titles created for [t], in the current UI language.
  List<String> templateColumns(BoardTemplate t) => switch (t) {
    BoardTemplate.basic => [columnTodo, columnInProgress, columnDone],
    BoardTemplate.development => [
      columnDevBacklog,
      columnDevTodo,
      columnDevInProgress,
      columnDevReview,
      columnDevDone,
    ],
    BoardTemplate.empty => const [],
  };

  String priority(CardPriority p) => switch (p) {
    CardPriority.low => priorityLow,
    CardPriority.medium => priorityMedium,
    CardPriority.high => priorityHigh,
  };
}

/// Accent per priority; paired with an icon so color is never the only cue.
Color priorityColor(CardPriority p, ColorScheme scheme) => switch (p) {
  CardPriority.low => scheme.outline,
  CardPriority.medium => AppColors.secondaryAccent,
  CardPriority.high => AppColors.accent,
};

IconData priorityIcon(CardPriority p) => switch (p) {
  CardPriority.low => Icons.keyboard_arrow_down,
  CardPriority.medium => Icons.drag_handle,
  CardPriority.high => Icons.keyboard_double_arrow_up,
};

/// Stable color for a free-text label.
Color labelColor(String label, ColorScheme scheme) {
  final palette = [
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    scheme.surfaceContainerHighest,
  ];
  final hash = label.codeUnits.fold<int>(
    0,
    (h, c) => (h * 31 + c) & 0x7fffffff,
  );
  return palette[hash % palette.length];
}
