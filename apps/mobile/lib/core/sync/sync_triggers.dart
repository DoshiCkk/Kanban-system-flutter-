import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Platform events that should start a sync cycle right away: the network
/// comes back or the app returns to the foreground (docs/sync.md §7).
Stream<void> platformSyncTriggers() {
  AppLifecycleListener? lifecycle;
  StreamSubscription<List<ConnectivityResult>>? connectivity;
  late final StreamController<void> controller;
  controller = StreamController<void>.broadcast(
    onListen: () {
      lifecycle = AppLifecycleListener(onResume: () => controller.add(null));
      connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) controller.add(null);
      });
    },
    onCancel: () async {
      lifecycle?.dispose();
      await connectivity?.cancel();
    },
  );
  return controller.stream;
}
