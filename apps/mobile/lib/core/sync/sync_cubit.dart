import 'dart:async';

import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Exposes the engine's status to widgets (indicator, sign-out warning).
class SyncCubit extends Cubit<SyncStatus> {
  SyncCubit(this._engine) : super(_engine.status) {
    _subscription = _engine.statusChanges.listen(emit);
  }

  final SyncEngine _engine;
  late final StreamSubscription<SyncStatus> _subscription;

  /// Returns true when everything reached the server.
  Future<bool> syncNow() async {
    final ok = await _engine.syncNow();
    return ok && _engine.status.pending == 0;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
