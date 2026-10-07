import 'dart:convert';

import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/sync/sync_api.dart';

/// In-memory model of the API's sync rules (docs/sync.md §4–5): field-level
/// last-writer-wins in arrival order, delete wins with cascades, parent
/// checks, opId idempotency and per-workspace `seq` paging.
class FakeSyncServer {
  FakeSyncServer({this.pageSize = 500});

  final int pageSize;
  final rows = <String, Map<String, Map<String, dynamic>>>{
    for (final e in _kindOf.keys) e: {},
  };
  final _results = <String, PushResult>{};
  var _seq = 0;
  var _clock = DateTime.utc(2026, 10, 7);

  /// Push/pull requests made, for assertions.
  int pushCalls = 0;
  int pullCalls = 0;

  static const _kindOf = {
    'board': 'boards',
    'column': 'columns',
    'card': 'cards',
    'checklistItem': 'checklistItems',
    'comment': 'comments',
  };

  static const _updateKeys = {
    'board': ['title'],
    'column': ['title', 'position', 'wipLimit'],
    'card': [
      'columnId',
      'title',
      'description',
      'assigneeId',
      'dueDate',
      'priority',
      'labels',
      'position',
    ],
    'checklistItem': ['text', 'done', 'position'],
    'comment': ['text'],
  };

  static const Map<String, Map<String, Object?>> _defaults = {
    'board': {'templateKey': null},
    'column': {'wipLimit': null},
    'card': {
      'description': '',
      'assigneeId': null,
      'dueDate': null,
      'priority': 'medium',
      'labels': <String>[],
    },
    'checklistItem': <String, Object?>{},
    'comment': {'mentions': <String>[]},
  };

  Map<String, dynamic>? _live(String entity, Object? id) {
    final row = rows[entity]![id];
    return row == null || row['deletedAt'] != null ? null : row;
  }

  void _touch(Map<String, dynamic> row) {
    _clock = _clock.add(const Duration(seconds: 1));
    row
      ..['seq'] = ++_seq
      ..['version'] = (row['version'] as int? ?? 0) + 1
      ..['updatedAt'] = _clock.toIso8601String();
  }

  PushResult _reject(String opId, String code) =>
      PushResult(opId: opId, status: PushStatus.rejected, code: code);

  List<PushResult> push(String userId, List<OutboxRow> ops) {
    pushCalls++;
    return [
      for (final op in ops)
        _results[op.opId] != null
            ? PushResult(opId: op.opId, status: PushStatus.duplicate)
            : _results[op.opId] = _apply(userId, op),
    ];
  }

  PushResult _apply(String userId, OutboxRow op) {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    final table = rows[op.entity]!;
    final existing = table[op.entityId];
    final applied = PushResult(opId: op.opId, status: PushStatus.applied);

    if (op.operation == 'create' && existing == null) {
      final String workspaceId;
      final extra = <String, dynamic>{};
      switch (op.entity) {
        case 'board':
          workspaceId = payload['workspaceId'] as String;
        case 'column':
          final board = _live('board', payload['boardId']);
          if (board == null) return _reject(op.opId, 'SYNC_PARENT_DELETED');
          workspaceId = board['workspaceId'] as String;
        case 'card':
          final column = _live('column', payload['columnId']);
          if (column == null) return _reject(op.opId, 'SYNC_PARENT_DELETED');
          workspaceId = column['workspaceId'] as String;
        default:
          final card = _live('card', payload['cardId']);
          if (card == null) return _reject(op.opId, 'SYNC_PARENT_DELETED');
          workspaceId = card['workspaceId'] as String;
          if (op.entity == 'comment') extra['authorId'] = userId;
      }
      final row = <String, dynamic>{
        'id': op.entityId,
        ..._defaults[op.entity]!,
        ...payload,
        ...extra,
        'workspaceId': workspaceId,
        'deletedAt': null,
      };
      _touch(row);
      table[op.entityId] = row;
      return applied;
    }
    if (existing == null) return _reject(op.opId, 'SYNC_NOT_FOUND');

    if (op.operation == 'delete') {
      if (existing['deletedAt'] == null) _delete(op.entity, existing);
      return applied;
    }
    if (existing['deletedAt'] != null) {
      return _reject(op.opId, 'SYNC_ENTITY_DELETED');
    }
    final changes = Map.of(payload)
      ..removeWhere((k, _) => !_updateKeys[op.entity]!.contains(k));
    if (op.entity == 'card' && changes['columnId'] != null) {
      final target = _live('column', changes['columnId']);
      if (target == null) return _reject(op.opId, 'SYNC_PARENT_DELETED');
    }
    existing.addAll(changes);
    _touch(existing);
    return applied;
  }

  void _delete(String entity, Map<String, dynamic> row) {
    row['deletedAt'] = _clock.toIso8601String();
    _touch(row);
    final id = row['id'];
    void cascade(String child, bool Function(Map<String, dynamic>) where) {
      for (final r in rows[child]!.values.toList()) {
        if (r['deletedAt'] == null && where(r)) _delete(child, r);
      }
    }

    switch (entity) {
      case 'board':
        cascade('column', (r) => r['boardId'] == id);
        cascade('card', (r) => r['boardId'] == id);
      case 'column':
        cascade('card', (r) => r['columnId'] == id);
      case 'card':
        cascade('checklistItem', (r) => r['cardId'] == id);
        cascade('comment', (r) => r['cardId'] == id);
    }
  }

  PullPage pull(String workspaceId, String since) {
    pullCalls++;
    final from = int.parse(since);
    final changed = [
      for (final MapEntry(key: entity, value: table) in rows.entries)
        for (final row in table.values)
          if (row['workspaceId'] == workspaceId && (row['seq'] as int) > from)
            (entity, row),
    ]..sort((a, b) => (a.$2['seq'] as int).compareTo(b.$2['seq'] as int));
    final taken = changed.take(pageSize).toList();
    final page = <String, List<WireRow>>{
      for (final kind in PullPage.kinds) kind: [],
    };
    for (final (entity, row) in taken) {
      final wire = Map<String, dynamic>.of(row)..remove('seq');
      if (entity != 'board') wire.remove('workspaceId');
      // Round-trip through JSON like the real API.
      page[_kindOf[entity]]!.add(
        jsonDecode(jsonEncode(wire)) as Map<String, dynamic>,
      );
    }
    return PullPage(
      rows: page,
      cursor: taken.isEmpty ? since : '${taken.last.$2['seq']}',
      hasMore: changed.length > pageSize,
    );
  }
}

/// One user's view of [server]. Set [offline] to simulate no network and
/// [removedFrom] for workspaces the user was kicked out of.
class FakeSyncApi implements SyncApi {
  FakeSyncApi(this.server, this.userId);

  final FakeSyncServer server;
  final String userId;
  bool offline = false;
  final removedFrom = <String>{};

  void _check() {
    if (offline) throw const ApiException(ApiErrorCode.network);
  }

  @override
  Future<List<PushResult>> push(List<OutboxRow> ops) async {
    _check();
    return server.push(userId, ops);
  }

  @override
  Future<PullPage> pull(String workspaceId, String since) async {
    _check();
    if (removedFrom.contains(workspaceId)) {
      throw const ApiException(ApiErrorCode.notFound, statusCode: 404);
    }
    return server.pull(workspaceId, since);
  }
}
