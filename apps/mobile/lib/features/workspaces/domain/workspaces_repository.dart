import 'package:flowboard/features/workspaces/domain/workspace.dart';

/// Online-only in phase 2; cached in Drift once sync lands (see backlog).
abstract interface class WorkspacesRepository {
  Future<List<Workspace>> list();

  Future<Workspace> create(String name);

  Future<Workspace> get(String workspaceId);

  Future<List<Member>> members(String workspaceId);

  Future<Invite> createInvite(String workspaceId);

  Future<InvitePreview> previewInvite(String token);

  Future<Workspace> acceptInvite(String token);

  Future<Member> updateRole(
    String workspaceId,
    String userId,
    WorkspaceRole role,
  );

  Future<void> removeMember(String workspaceId, String userId);
}
