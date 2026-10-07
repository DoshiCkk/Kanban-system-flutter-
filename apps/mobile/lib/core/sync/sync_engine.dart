import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/sync/outbox.dart';
import 'package:flowboard/core/sync/sync_api.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flutter/foundation.dart';

enum SyncPhase {
  /// Last cycle succeeded (or none ran yet).
  idle,
  syncing,

  /// Server unreachable; retrying with backoff.
  offline,

  /// Server answered with an error; retrying with backoff.
  error,
}

class SyncStatus extends Equatable {
  const SyncStatus({this.phase = SyncPhase.idle, this.pending = 0});

  final SyncPhase phase;

  /// Outbox ops not yet acknowledged by the server.
  final int pending;

  bool get synced => phase == SyncPhase.idle && pending == 0;

  SyncStatus copyWith({SyncPhase? phase, int? pending}) => SyncStatus(
    phase: phase ?? this.phase,
    pending: pending ?? this.pending,
  );

  @override
  List<Object?> get props => [phase, pending];
}

/// Push-then-pull loop of docs/sync.md §7. Cycles never overlap: triggers
/// that arrive during a cycle schedule exactly one more.
class SyncEngine {
  SyncEngine({
    required this._store,
    required this._api,
    this.debounce = const Duration(milliseconds: 500),
    this.period = const Duration(seconds: 60),
    Random? random,
  }) : _random = random ?? Random();

  static const pushBatchSize = 100;
  static const maxBackoff = Duration(minutes: 5);

  final SyncStore _store;
  final SyncApi _api;
  final Random _random;
  final Duration debounce;
  final Duration period;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _periodicTimer;
  Future<bool>? _running;
  bool _again = false;
  bool _started = false;
  int _failures = 0;
  int _lastPending = 0;

  SyncStatus get status => _current;

  Stream<SyncStatus> get statusChanges => _status.stream;

  bool get isStarted => _started;

  void _emit(SyncStatus status) {
    if (status == _current) return;
    _current = status;
    _status.add(status);
  }

  /// Starts syncing for the signed-in user. [triggers] fire an immediate
  /// cycle (network back, app resumed).
  void start({Stream<void>? triggers}) {
    if (_started) return;
    _started = true;
    _subscriptions
      ..add(_store.watchPendingCount().listen(_onPending))
      ..add(_store.watchWorkspaceIds().skip(1).listen((_) => _schedule()));
    if (triggers != null) {
      _subscriptions.add(triggers.listen((_) => unawaited(syncNow())));
    }
    _periodicTimer = Timer.periodic(period, (_) {
      if (_running == null) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  /// Stops all triggers and waits for a running cycle to finish.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _periodicTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    try {
      await _running;
    } on Object {
      // The cycle reports its own errors through the status.
    }
    _failures = 0;
    _lastPending = 0;
    _emit(const SyncStatus());
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
  }

  void _onPending(int count) {
    _emit(_current.copyWith(pending: count));
    // Only new local changes schedule a cycle, not ops we just pushed.
    if (count > _lastPending) _schedule();
    _lastPending = count;
  }

  void _schedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Runs a cycle now (or joins the running one, then runs once more).
  /// Returns whether the last cycle succeeded.
  Future<bool> syncNow() {
    if (!_started) return Future.value(false);
    _retryTimer?.cancel();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<bool> _loop() async {
    var ok = false;
    do {
      _again = false;
      ok = await _cycle();
    } while (ok && _again && _started);
    return ok;
  }

  Future<bool> _cycle() async {
    _emit(_current.copyWith(phase: SyncPhase.syncing));
    try {
      await _push();
      await _pull();
      _failures = 0;
      _emit(_current.copyWith(phase: SyncPhase.idle));
      return true;
    } on ApiException catch (e) {
      _emit(
        _current.copyWith(
          phase: e.code == ApiErrorCode.network
              ? SyncPhase.offline
              : SyncPhase.error,
        ),
      );
      _scheduleRetry();
      return false;
    } on Object catch (e, stack) {
      // A local bug must not wedge the engine in "syncing".
      debugPrint('sync: cycle failed: $e\n$stack');
      _emit(_current.copyWith(phase: SyncPhase.error));
      _scheduleRetry();
      return false;
    }
  }

  void _scheduleRetry() {
    if (!_started) return;
    _failures++;
    final seconds = min(1 << min(_failures - 1, 16), maxBackoff.inSeconds);
    // Jitter: 50–100 % of the delay, so devices do not retry in lockstep.
    final delay = Duration(
      milliseconds: (seconds * 1000 * (0.5 + _random.nextDouble() / 2)).round(),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(syncNow()));
  }

  Future<void> _push() async {
    var resync = false;
    while (_started) {
      final batch = await _store.nextBatch(pushBatchSize);
      if (batch.isEmpty) break;
      final ids = [for (final op in batch) op.opId];
      List<PushResult> results;
      try {
        results = await _api.push(batch);
      } on ApiException catch (e) {
        await _store.markAttempted(ids);
        if (_isRetryable(e)) rethrow;
        // A malformed batch is a client bug; never let it block the queue.
        debugPrint('sync: dropping batch rejected with ${e.code}');
        await _store.completeOps(ids);
        resync = true;
        continue;
      }

      final byId = {for (final op in batch) op.opId: op};
      for (final result in results) {
        if (result.status != PushStatus.rejected) continue;
        final op = byId[result.opId];
        if (op == null) continue;
        debugPrint('sync: ${op.entity} ${op.operation} ${result.code}');
        if (op.operation == SyncOperation.create.name) {
          await _store.discardCreate(op.entity, op.entityId);
        } else {
          resync = true;
        }
      }
      await _store.completeOps(ids);
    }
    // A rejected update leaves the local row ahead of the server; a full
    // pull restores the server's version (docs/sync.md §5).
    if (resync) await _store.resetCursors();
  }

  bool _isRetryable(ApiException e) => switch (e.code) {
    ApiErrorCode.network ||
    ApiErrorCode.server ||
    ApiErrorCode.rateLimited ||
    ApiErrorCode.unauthorized ||
    ApiErrorCode.unknown => true,
    _ => false,
  };

  Future<void> _pull() async {
    for (final workspaceId in await _store.workspaceIds()) {
      var hasMore = true;
      while (hasMore && _started) {
        final since = await _store.cursor(workspaceId);
        final PullPage page;
        try {
          page = await _api.pull(workspaceId, since);
        } on ApiException catch (e) {
          if (e.code != ApiErrorCode.notFound) rethrow;
          // Removed from the workspace (docs/sync.md §6).
          await _store.forgetWorkspace(workspaceId);
          break;
        }
        await _store.applyPull(workspaceId, page);
        hasMore = page.hasMore;
      }
    }
  }
}
