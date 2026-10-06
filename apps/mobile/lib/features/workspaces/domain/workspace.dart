import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

enum WorkspaceRole {
  owner,
  admin,
  member;

  bool get canInvite => this == owner || this == admin;

  bool get canRename => this == owner || this == admin;

  bool get canManageRoles => this == owner;

  /// Whether a member with this role may remove a member with [target] role.
  bool canRemove(WorkspaceRole target) => switch (this) {
    owner => target != owner,
    admin => target == member,
    member => false,
  };
}

@freezed
abstract class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    required WorkspaceRole role,
    required int memberCount,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}

@freezed
abstract class MemberUser with _$MemberUser {
  const factory MemberUser({
    required String id,
    required String email,
    required String name,
    String? avatarUrl,
  }) = _MemberUser;

  factory MemberUser.fromJson(Map<String, dynamic> json) =>
      _$MemberUserFromJson(json);
}

@freezed
abstract class Member with _$Member {
  const factory Member({
    required MemberUser user,
    required WorkspaceRole role,
    required DateTime joinedAt,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);
}

@freezed
abstract class Invite with _$Invite {
  const factory Invite({required String token, required DateTime expiresAt}) =
      _Invite;

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);

  const Invite._();

  /// Deep link handled by the app router (`/invite/:token`).
  Uri get link => Uri(scheme: 'flowboard', host: 'app', path: '/invite/$token');
}

@freezed
abstract class InvitePreview with _$InvitePreview {
  const factory InvitePreview({
    required String workspaceId,
    required String workspaceName,
    required int memberCount,
    required DateTime expiresAt,
    required bool alreadyMember,
  }) = _InvitePreview;

  factory InvitePreview.fromJson(Map<String, dynamic> json) =>
      _$InvitePreviewFromJson(json);
}

/// Extracts an invite token from a pasted link or a bare token.
String? parseInviteToken(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final segments = uri?.pathSegments ?? const <String>[];
  final index = segments.indexOf('invite');
  if (index >= 0 && index + 1 < segments.length) {
    return segments[index + 1];
  }
  // A bare base64url token (43 chars for 32 random bytes).
  return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(text) ? text : null;
}
