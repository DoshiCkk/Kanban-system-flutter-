import 'dart:ui';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Last-resort handling of errors nothing else caught. They are logged
/// (crash reporting is out of MVP, see docs/backlog.md) and never close the
/// app; in release builds a broken widget shows [BrokenWidgetPlaceholder]
/// instead of a grey box.
void installErrorHandlers({
  void Function(Object error, StackTrace? stack)? log,
}) {
  final report = log ?? _debugLog;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    report(error, stack);
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const BrokenWidgetPlaceholder();
  }
}

void _debugLog(Object error, StackTrace? stack) =>
    debugPrint('Uncaught error: $error\n$stack');

/// Shown in place of a widget that failed to build (release builds).
class BrokenWidgetPlaceholder extends StatelessWidget {
  const BrokenWidgetPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // The failure may sit above Localizations or Theme.
    final message = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    )?.errorWidgetMessage;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
