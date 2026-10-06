// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Workspace _$WorkspaceFromJson(Map<String, dynamic> json) => _Workspace(
  id: json['id'] as String,
  name: json['name'] as String,
  role: $enumDecode(_$WorkspaceRoleEnumMap, json['role']),
  memberCount: (json['memberCount'] as num).toInt(),
);

Map<String, dynamic> _$WorkspaceToJson(_Workspace instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': _$WorkspaceRoleEnumMap[instance.role]!,
      'memberCount': instance.memberCount,
    };

const _$WorkspaceRoleEnumMap = {
  WorkspaceRole.owner: 'owner',
  WorkspaceRole.admin: 'admin',
  WorkspaceRole.member: 'member',
};

_MemberUser _$MemberUserFromJson(Map<String, dynamic> json) => _MemberUser(
  id: json['id'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$MemberUserToJson(_MemberUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'name': instance.name,
      'avatarUrl': instance.avatarUrl,
    };

_Member _$MemberFromJson(Map<String, dynamic> json) => _Member(
  user: MemberUser.fromJson(json['user'] as Map<String, dynamic>),
  role: $enumDecode(_$WorkspaceRoleEnumMap, json['role']),
  joinedAt: DateTime.parse(json['joinedAt'] as String),
);

Map<String, dynamic> _$MemberToJson(_Member instance) => <String, dynamic>{
  'user': instance.user,
  'role': _$WorkspaceRoleEnumMap[instance.role]!,
  'joinedAt': instance.joinedAt.toIso8601String(),
};

_Invite _$InviteFromJson(Map<String, dynamic> json) => _Invite(
  token: json['token'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$InviteToJson(_Invite instance) => <String, dynamic>{
  'token': instance.token,
  'expiresAt': instance.expiresAt.toIso8601String(),
};

_InvitePreview _$InvitePreviewFromJson(Map<String, dynamic> json) =>
    _InvitePreview(
      workspaceId: json['workspaceId'] as String,
      workspaceName: json['workspaceName'] as String,
      memberCount: (json['memberCount'] as num).toInt(),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      alreadyMember: json['alreadyMember'] as bool,
    );

Map<String, dynamic> _$InvitePreviewToJson(_InvitePreview instance) =>
    <String, dynamic>{
      'workspaceId': instance.workspaceId,
      'workspaceName': instance.workspaceName,
      'memberCount': instance.memberCount,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'alreadyMember': instance.alreadyMember,
    };
