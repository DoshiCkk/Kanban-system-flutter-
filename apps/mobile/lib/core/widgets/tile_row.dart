import 'package:flutter/material.dart';

/// Equal-height tiles side by side (counters on home and profile). With
/// large text they stack one per row instead of breaking labels mid-word.
class TileRow extends StatelessWidget {
  const TileRow({required this.children, super.key});

  final List<Widget> children;

  /// Text scale from which the tiles stack.
  static const stackScale = 1.5;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) >= stackScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            child,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ],
      ),
    );
  }
}
