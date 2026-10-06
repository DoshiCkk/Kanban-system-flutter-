import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/settings/data/prefs_settings_repository.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
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

  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<SettingsRepository>(PrefsSettingsRepository(prefs))
    ..registerSingleton<GoRouter>(createRouter());
}
