import 'package:dio/dio.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:uuid/uuid.dart';

typedef _Json = Map<String, dynamic>;

class WorkspacesRepositoryImpl implements WorkspacesRepository {
  WorkspacesRepositoryImpl(this._dio, {this._uuid = const Uuid()});

  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<List<Workspace>> list() => guardApi(() async {
    final res = await _dio.get<List<dynamic>>('/workspaces');
    return res.data!.cast<_Json>().map(Workspace.fromJson).toList();
  });

  @override
  Future<Workspace> create(String name) => guardApi(() async {
    final res = await _dio.post<_Json>(
      '/workspaces',
      data: {'id': _uuid.v4(), 'name': name.trim()},
    );
    return Workspace.fromJson(res.data!);
  });

  @override
  Future<Workspace> get(String workspaceId) => guardApi(() async {
    final res = await _dio.get<_Json>('/workspaces/$workspaceId');
    return Workspace.fromJson(res.data!);
  });

  @override
  Future<List<Member>> members(String workspaceId) => guardApi(() async {
    final res = await _dio.get<List<dynamic>>(
      '/workspaces/$workspaceId/members',
    );
    return res.data!.cast<_Json>().map(Member.fromJson).toList();
  });

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
}
