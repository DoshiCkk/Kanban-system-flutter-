import 'dart:async';

import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/core/notifications/notification_service.dart';
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

  /// Signs in as the account [register]ed with [email], else as [testUser].
  @override
  Future<User> login({required String email, required String password}) =>
      _signIn(
        registered.where((u) => u.email == email).firstOrNull ??
            testUser.copyWith(email: email),
      );

  /// Accounts created through [register]; the user signs in afterwards.
  final registered = <User>[];

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  }) async {
    final error = failWith;
    if (error != null) throw ApiException(error);
    registered.add(User(id: 'u2', email: email, name: name, locale: locale));
  }

  @override
  Future<User> updateName(String name) async {
    final error = failWith;
    if (error != null) throw ApiException(error);
    final user = _user!.copyWith(name: name);
    _user = user;
    _controller.add(user);
    return user;
  }

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
    // Like the real repository clearing secure storage first: the null user
    // reaches listeners only after logout() has returned.
    await Future<void>.value();
    _user = null;
    _controller.add(null);
  }
}

class FakeWorkspacesRepository implements WorkspacesRepository {
  final workspaces = <Workspace>[];

  /// Members besides [testUser] (the owner).
  final teammates = <MemberUser>[];
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
      for (final user in teammates)
        Member(
          user: user,
          role: WorkspaceRole.member,
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

/// Push notifications the test drives by hand.
class FakeNotificationService implements NotificationService {
  final openedPushes = StreamController<PushTarget>.broadcast();
  final foregroundPushes = StreamController<ForegroundPush>.broadcast();
  final locales = <String>[];
  bool started = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  void setLocale(String languageCode) => locales.add(languageCode);

  @override
  Future<void> retryRegistration() async {}

  @override
  Stream<PushTarget> get opened => openedPushes.stream;

  @override
  Stream<ForegroundPush> get foreground => foregroundPushes.stream;
}
