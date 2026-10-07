import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:uuid/uuid.dart';

typedef _Json = Map<String, dynamic>;

/// Workspaces live on the server. Reads go to the network and refresh a
/// local cache; when offline the cache is returned instead, so boards stay
/// reachable in airplane mode.
class WorkspacesRepositoryImpl implements WorkspacesRepository {
  WorkspacesRepositoryImpl(this._dio, this._db, {this._uuid = const Uuid()});

  final Dio _dio;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<List<Workspace>> list() => _cached(
    remote: () async {
      final res = await _dio.get<List<dynamic>>('/workspaces');
      final list = res.data!.cast<_Json>().map(Workspace.fromJson).toList();
      await _db.transaction(() async {
        await _db.delete(_db.cachedWorkspaces).go();
        await _db.batch(
          (b) => b.insertAll(_db.cachedWorkspaces, list.map(_toCacheRow)),
        );
      });
      return list;
    },
    local: () async {
      final rows = await (_db.select(
        _db.cachedWorkspaces,
      )..orderBy([(w) => OrderingTerm.asc(w.name)])).get();
      return rows.map(_fromCacheRow).toList();
    },
  );

  @override
  Future<Workspace> create(String name) => guardApi(() async {
    final res = await _dio.post<_Json>(
      '/workspaces',
      data: {'id': _uuid.v4(), 'name': name.trim()},
    );
    final workspace = Workspace.fromJson(res.data!);
    await _db
        .into(_db.cachedWorkspaces)
        .insertOnConflictUpdate(_toCacheRow(workspace));
    return workspace;
  });

  @override
  Future<Workspace> get(String workspaceId) => _cached(
    remote: () async {
      final res = await _dio.get<_Json>('/workspaces/$workspaceId');
      final workspace = Workspace.fromJson(res.data!);
      await _db
          .into(_db.cachedWorkspaces)
          .insertOnConflictUpdate(_toCacheRow(workspace));
      return workspace;
    },
    local: () async {
      final row = await (_db.select(
        _db.cachedWorkspaces,
      )..where((w) => w.id.equals(workspaceId))).getSingleOrNull();
      return row == null ? null : _fromCacheRow(row);
    },
  );

  @override
  Future<List<Member>> members(String workspaceId) => _cached(
    remote: () async {
      final res = await _dio.get<List<dynamic>>(
        '/workspaces/$workspaceId/members',
      );
      final members = res.data!.cast<_Json>().map(Member.fromJson).toList();
      await _db.transaction(() async {
        await (_db.delete(
          _db.cachedMembers,
        )..where((m) => m.workspaceId.equals(workspaceId))).go();
        await _db.batch(
          (b) => b.insertAll(_db.cachedMembers, [
            for (final m in members) _toMemberRow(workspaceId, m),
          ]),
        );
      });
      return members;
    },
    local: () async {
      final rows =
          await (_db.select(_db.cachedMembers)
                ..where((m) => m.workspaceId.equals(workspaceId))
                ..orderBy([(m) => OrderingTerm.asc(m.joinedAt)]))
              .get();
      return rows.isEmpty ? null : rows.map(_fromMemberRow).toList();
    },
  );

  @override
  Future<Invite> createInvite(String workspaceId) => guardApi(() async {
    final res = await _dio.post<_Json>('/workspaces/$workspaceId/invites');
    return Invite.fromJson(res.data!);
  });

  @override
  Future<InvitePreview> previewInvite(String token) => guardApi(() async {
    final res = await _dio.get<_Json>(
      '/invites/${Uri.encodeComponent(token)}',
    );
    return InvitePreview.fromJson(res.data!);
  });

  @override
  Future<Workspace> acceptInvite(String token) => guardApi(() async {
    final res = await _dio.post<_Json>(
      '/invites/${Uri.encodeComponent(token)}/accept',
    );
    return Workspace.fromJson(res.data!);
  });

  @override
  Future<Member> updateRole(
    String workspaceId,
    String userId,
    WorkspaceRole role,
  ) => guardApi(() async {
    final res = await _dio.patch<_Json>(
      '/workspaces/$workspaceId/members/$userId',
      data: {'role': role.name},
    );
    return Member.fromJson(res.data!);
  });

  @override
  Future<void> removeMember(String workspaceId, String userId) => guardApi(
    () => _dio.delete<void>('/workspaces/$workspaceId/members/$userId'),
  );

  /// Network first; on a connectivity error fall back to [local] if it has
  /// data, otherwise rethrow.
  Future<T> _cached<T extends Object>({
    required Future<T> Function() remote,
    required Future<T?> Function() local,
  }) async {
    try {
      return await guardApi(remote);
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.network) rethrow;
      final cached = await local();
      if (cached == null) rethrow;
      return cached;
    }
  }

  static CachedWorkspacesCompanion _toCacheRow(Workspace w) =>
      CachedWorkspacesCompanion.insert(
        id: w.id,
        name: w.name,
        role: w.role.name,
        memberCount: w.memberCount,
      );

  static Workspace _fromCacheRow(WorkspaceCacheRow row) => Workspace(
    id: row.id,
    name: row.name,
    role: WorkspaceRole.values.byName(row.role),
    memberCount: row.memberCount,
  );

  static CachedMembersCompanion _toMemberRow(String workspaceId, Member m) =>
      CachedMembersCompanion.insert(
        workspaceId: workspaceId,
        userId: m.user.id,
        name: m.user.name,
        email: m.user.email,
        avatarUrl: Value(m.user.avatarUrl),
        role: m.role.name,
        joinedAt: m.joinedAt,
      );

  static Member _fromMemberRow(MemberCacheRow row) => Member(
    user: MemberUser(
      id: row.userId,
      email: row.email,
      name: row.name,
      avatarUrl: row.avatarUrl,
    ),
    role: WorkspaceRole.values.byName(row.role),
    joinedAt: row.joinedAt,
  );
}
