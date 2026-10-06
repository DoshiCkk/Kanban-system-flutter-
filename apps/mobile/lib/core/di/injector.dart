import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/network/api_client.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/auth/data/auth_api.dart';
import 'package:flowboard/features/auth/data/auth_repository_impl.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
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

  final sessionStorage = SecureSessionStorage();
  final tokens = TokenStore(sessionStorage);
  late final AuthRepositoryImpl authRepository;
  final dio = createApiClient(
    config: config,
    tokens: tokens,
    onSessionExpired: () => unawaited(authRepository.onSessionExpired()),
  );
  authRepository = AuthRepositoryImpl(
    api: AuthApi(dio),
    tokens: tokens,
    storage: sessionStorage,
  );
  // Restores from secure storage only, so startup works offline.
  await authRepository.restore();
  final authCubit = AuthCubit(authRepository);
  unawaited(authCubit.refreshProfile());

  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<SettingsRepository>(PrefsSettingsRepository(prefs))
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<WorkspacesRepository>(WorkspacesRepositoryImpl(dio))
    ..registerSingleton<AuthCubit>(authCubit)
    ..registerSingleton<GoRouter>(createRouter(authCubit));
}
