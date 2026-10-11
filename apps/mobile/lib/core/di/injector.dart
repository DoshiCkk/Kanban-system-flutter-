import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/access_token.dart';
import 'package:flowboard/core/network/api_client.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/core/sync/realtime.dart';
import 'package:flowboard/core/sync/socket_io_transport.dart';
import 'package:flowboard/core/sync/sync_api.dart';
import 'package:flowboard/core/sync/sync_cubit.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/core/sync/sync_triggers.dart';
import 'package:flowboard/features/auth/data/auth_api.dart';
import 'package:flowboard/features/auth/data/auth_repository_impl.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/boards_repository.dart';
import 'package:flowboard/features/settings/data/prefs_settings_repository.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
import 'package:flowboard/features/workspaces/data/workspaces_repository_impl.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies(AppConfig config) async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: PrefsSettingsRepository.keys,
    ),
  );

  final db = AppDatabase();
  final sessionStorage = SecureSessionStorage();
  final tokens = TokenStore(sessionStorage);
  late final AuthRepositoryImpl authRepository;
  final api = createApiClient(
    config: config,
    tokens: tokens,
    onSessionExpired: () => unawaited(authRepository.onSessionExpired()),
  );
  final dio = api.dio;
  authRepository = AuthRepositoryImpl(
    api: AuthApi(dio),
    tokens: tokens,
    storage: sessionStorage,
    prepareLocalData: db.claimFor,
  );
  final realtime = RealtimeClient(
    transport: SocketIoTransport(config.apiBaseUrl),
    token: AccessTokenSource(tokens, api.auth.refreshAccessToken).call,
  );
  final boards = DriftBoardsRepository(db, watchRoom: realtime.watch);
  // Restores from secure storage only, so startup works offline.
  await authRepository.restore();
  final authCubit = AuthCubit(authRepository);
  unawaited(authCubit.refreshProfile());

  final syncEngine = SyncEngine(store: SyncStore(db), api: DioSyncApi(dio));
  final syncTriggers = platformSyncTriggers();
  // Sync and live updates run only while signed in; claimFor already
  // prepared the data.
  void followSession(AuthState state) {
    if (state.isAuthenticated) {
      realtime.start();
      syncEngine.start(triggers: [syncTriggers, realtime.changes]);
    } else {
      unawaited(realtime.stop());
      unawaited(syncEngine.stop());
    }
  }

  followSession(authCubit.state);
  authCubit.stream.listen(followSession);
  // A board created offline can be joined only after a sync pushed it.
  syncEngine.statusChanges
      .where((s) => s.phase == SyncPhase.idle)
      .listen((_) => realtime.retryFailedJoins());

  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<SettingsRepository>(PrefsSettingsRepository(prefs))
    ..registerSingleton<AppDatabase>(db)
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<WorkspacesRepository>(
      WorkspacesRepositoryImpl(dio, db),
    )
    ..registerSingleton<BoardsRepository>(boards)
    ..registerSingleton<CardRepository>(boards)
    ..registerSingleton<AuthCubit>(authCubit)
    ..registerSingleton<SyncEngine>(syncEngine)
    ..registerSingleton<SyncCubit>(SyncCubit(syncEngine))
    ..registerSingleton<GoRouter>(createRouter(authCubit));
}
