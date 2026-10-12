import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowboard/app.dart';
import 'package:flowboard/bootstrap.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/sync_cubit.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/domain/user.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flowboard/features/comments/data/drift_comments_repository.dart';
import 'package:flowboard/features/comments/domain/comments_repository.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_sync_server.dart';
import 'fakes.dart';
import 'in_memory_settings_repository.dart';

class TestApp {
  TestApp({
    required this.auth,
    required this.workspaces,
    required this.settings,
    required this.authCubit,
    required this.router,
    required this.boards,
    required this.syncApi,
    required this.syncEngine,
    required this.notifications,
  });

  final FakeAuthRepository auth;
  final FakeWorkspacesRepository workspaces;
  final InMemorySettingsRepository settings;
  final AuthCubit authCubit;
  final GoRouter router;
  final DriftBoardsRepository boards;
  final FakeSyncApi syncApi;

  /// Not started; tests start it when they exercise sync.
  final SyncEngine syncEngine;
  final FakeNotificationService notifications;
}

/// Pumps the full app (real router + cubits) on top of fake repositories.
///
/// With [splash], the app starts behind [AppBootstrap] like in `main.dart`
/// and the call returns while the splash is still shown.
///
/// [seed] fills the database before the app is built. Once the app runs,
/// its Drift streams query in the fake-async zone, and a real-zone write
/// would wait forever for their lock.
Future<TestApp> pumpFlowBoard(
  WidgetTester tester, {
  bool signedIn = true,
  User user = testUser,
  String? initialLocation,
  ThemeMode themeMode = ThemeMode.system,
  List<Workspace> workspaces = const [],
  Future<void> Function(DriftBoardsRepository boards)? seed,
  Duration? splash,
}) async {
  await getIt.reset();
  final auth = FakeAuthRepository(user: signedIn ? user : null);
  final workspacesRepository = FakeWorkspacesRepository()
    ..workspaces.addAll(workspaces);
  final settings = InMemorySettingsRepository(
    AppSettings(language: AppLanguage.en, themeMode: themeMode),
  );
  // Synchronous stream closing keeps drift timers off the fake test clock.
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  final boards = DriftBoardsRepository(db);
  getIt
    ..registerSingleton<AuthRepository>(auth)
    ..registerSingleton<WorkspacesRepository>(workspacesRepository)
    ..registerSingleton<BoardsRepository>(boards)
    ..registerSingleton<CardRepository>(boards)
    ..registerSingleton<CommentsRepository>(DriftCommentsRepository(db));
  if (seed != null) await tester.runAsync(() => seed(boards));

  final syncApi = FakeSyncApi(FakeSyncServer(), testUser.id);
  final syncEngine = SyncEngine(store: SyncStore(db), api: syncApi);
  final syncCubit = SyncCubit(syncEngine);
  final notifications = FakeNotificationService();
  final authCubit = AuthCubit(auth);
  final router = createRouter(authCubit);
  addTearDown(() async {
    router.dispose();
    await authCubit.close();
    await syncCubit.close();
    await syncEngine.dispose();
    await getIt.reset();
    await db.close();
  });
  if (initialLocation != null) router.go(initialLocation);

  final app = FlowBoardApp(
    settingsRepository: settings,
    authCubit: authCubit,
    syncCubit: syncCubit,
    router: router,
    notifications: notifications,
  );
  if (splash == null) {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  } else {
    // The splash spins until [splash] passes; the test pumps past it.
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () async {},
        minimumSplash: splash,
        settings: settings.settings,
        builder: (_) => app,
      ),
    );
  }
  return TestApp(
    auth: auth,
    workspaces: workspacesRepository,
    settings: settings,
    authCubit: authCubit,
    router: router,
    boards: boards,
    syncApi: syncApi,
    syncEngine: syncEngine,
    notifications: notifications,
  );
}
