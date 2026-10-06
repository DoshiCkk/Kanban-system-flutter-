import 'dart:async';

import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/domain/user.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';

const testUser = User(id: 'u1', email: 'aigerim@example.com', name: 'Aigerim');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._user});

  final _controller = StreamController<User?>.broadcast();
  User? _user;

  /// When set, login/register throw this error.
  ApiErrorCode? failWith;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get userChanges => _controller.stream;

  void expireSession() {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<User?> restore() async => _user;

  @override
  Future<User> login({required String email, required String password}) =>
      _signIn(testUser.copyWith(email: email));

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  }) => _signIn(User(id: 'u2', email: email, name: name, locale: locale));

  Future<User> _signIn(User user) async {
    final error = failWith;
    if (error != null) throw ApiException(error);
    _user = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<User?> refreshProfile() async => _user;

  @override
  Future<void> logout() async {
    _user = null;
    _controller.add(null);
  }
}

class FakeWorkspacesRepository implements WorkspacesRepository {
  final workspaces = <Workspace>[];
  ApiErrorCode? failWith;
  var _nextId = 0;

  void _maybeFail() {
    final error = failWith;
    if (error != null) throw ApiException(error);
  }

  @override
  Future<List<Workspace>> list() async {
    _maybeFail();
    return List.of(workspaces);
  }

  @override
  Future<Workspace> create(String name) async {
    _maybeFail();
    _nextId += 1;
    final workspace = Workspace(
      id: 'w$_nextId',
      name: name,
      role: WorkspaceRole.owner,
      memberCount: 1,
    );
    workspaces.add(workspace);
    return workspace;
  }

  @override
  Future<Workspace> get(String workspaceId) async {
    _maybeFail();
    return workspaces.firstWhere((w) => w.id == workspaceId);
  }

  @override
  Future<List<Member>> members(String workspaceId) async {
    _maybeFail();
    return [
      Member(
        user: MemberUser(
          id: testUser.id,
          email: testUser.email,
          name: testUser.name,
        ),
        role: WorkspaceRole.owner,
        joinedAt: DateTime(2026),
      ),
    ];
  }

  @override
  Future<Invite> createInvite(String workspaceId) async => Invite(
    token: 'token-abcdefghijklmnopqrstuvwxyz',
    expiresAt: DateTime(2026, 10, 13),
  );

  @override
  Future<InvitePreview> previewInvite(String token) async => InvitePreview(
    workspaceId: 'w-invited',
    workspaceName: 'Invited team',
    memberCount: 3,
    expiresAt: DateTime(2026, 10, 13),
    alreadyMember: false,
  );

  @override
  Future<Workspace> acceptInvite(String token) async {
    _maybeFail();
    const workspace = Workspace(
      id: 'w-invited',
      name: 'Invited team',
      role: WorkspaceRole.member,
      memberCount: 4,
    );
    workspaces.add(workspace);
    return workspace;
  }

  @override
  Future<Member> updateRole(
    String workspaceId,
    String userId,
    WorkspaceRole role,
  ) => throw UnimplementedError();

  @override
  Future<void> removeMember(String workspaceId, String userId) async {}
}

class InMemorySessionStorage implements SessionStorage {
  AuthTokens? tokens;
  String? userJson;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeTokens(AuthTokens value) async => tokens = value;

  @override
  Future<String?> readUserJson() async => userJson;

  @override
  Future<void> writeUserJson(String json) async => userJson = json;

  @override
  Future<void> clear() async {
    tokens = null;
    userJson = null;
  }
}
