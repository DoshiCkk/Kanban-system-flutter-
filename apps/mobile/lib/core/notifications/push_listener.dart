import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/notifications/notification_service.dart';
import 'package:flutter/material.dart';

/// Sits above the router (MaterialApp.builder): opens the card of a tapped
/// push, shows pushes that arrive while the app is open as a snackbar, and
/// keeps the push language in step with the UI language.
class PushListener extends StatefulWidget {
  const PushListener({
    required this.notifications,
    required this.onOpen,
    required this.child,
    super.key,
  });

  final NotificationService notifications;
  final void Function(PushTarget target) onOpen;
  final Widget child;

  @override
  State<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends State<PushListener> {
  late final List<StreamSubscription<Object>> _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = [
      widget.notifications.opened.listen((t) => widget.onOpen(t)),
      widget.notifications.foreground.listen(_show),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.notifications.setLocale(
      Localizations.localeOf(context).languageCode,
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  void _show(ForegroundPush push) {
    final target = push.target;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              push.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (push.body.isNotEmpty) Text(push.body),
          ],
        ),
        action: target == null
            ? null
            : SnackBarAction(
                label: context.l10n.pushOpen,
                onPressed: () => widget.onOpen(target),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
