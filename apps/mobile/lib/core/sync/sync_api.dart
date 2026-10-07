import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/api_exception.dart';

enum PushStatus { applied, duplicate, rejected }

class PushResult {
  const PushResult({required this.opId, required this.status, this.code});

  factory PushResult.fromJson(Map<String, dynamic> json) => PushResult(
    opId: json['opId'] as String,
    status: PushStatus.values.byName(json['status'] as String),
    code: json['code'] as String?,
  );

  final String opId;
  final PushStatus status;

  /// `SYNC_*` rejection code (docs/sync.md §5).
  final String? code;
}

typedef WireRow = Map<String, dynamic>;

/// One page of `GET /sync/pull`. Kinds are listed parent-first.
class PullPage {
  const PullPage({
    required this.rows,
    required this.cursor,
    required this.hasMore,
  });

  factory PullPage.fromJson(Map<String, dynamic> json) => PullPage(
    rows: {
      for (final kind in kinds)
        kind: [
          for (final row in json[kind] as List<dynamic>? ?? const [])
            row as WireRow,
        ],
    },
    cursor: json['cursor'] as String,
    hasMore: json['hasMore'] as bool,
  );

  static const kinds = [
    'boards',
    'columns',
    'cards',
    'checklistItems',
    'comments',
  ];

  final Map<String, List<WireRow>> rows;
  final String cursor;
  final bool hasMore;
}

abstract interface class SyncApi {
  Future<List<PushResult>> push(List<OutboxRow> ops);

  Future<PullPage> pull(String workspaceId, String since);
}

class DioSyncApi implements SyncApi {
  DioSyncApi(this._dio);

  final Dio _dio;

  @override
  Future<List<PushResult>> push(List<OutboxRow> ops) => guardApi(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/sync/push',
      data: {
        'ops': [
          for (final op in ops)
            {
              'opId': op.opId,
              'entity': op.entity,
              'entityId': op.entityId,
              'operation': op.operation,
              'payload': jsonDecode(op.payload),
            },
        ],
      },
    );
    return [
      for (final r in res.data!['results'] as List<dynamic>)
        PushResult.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Future<PullPage> pull(String workspaceId, String since) => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/sync/pull',
      queryParameters: {'workspaceId': workspaceId, 'since': since},
    );
    return PullPage.fromJson(res.data!);
  });
}
