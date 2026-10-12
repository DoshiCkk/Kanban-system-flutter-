import 'package:flowboard/app.dart';
import 'package:flowboard/bootstrap.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/core/errors/error_handling.dart';
import 'package:flowboard/features/settings/data/prefs_settings_repository.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  final prefs = await openPreferences();
  runApp(
    AppBootstrap(
      settings: PrefsSettingsRepository(prefs).load(),
      initialize: () =>
          configureDependencies(AppConfig.fromEnvironment(), prefs),
      builder: (_) => FlowBoardApp(
        settingsRepository: getIt(),
        authCubit: getIt(),
        syncCubit: getIt(),
        router: getIt(),
        notifications: getIt(),
      ),
    ),
  );
}
