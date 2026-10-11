import 'package:flowboard/app.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/core/errors/error_handling.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  await configureDependencies(AppConfig.fromEnvironment());
  runApp(
    FlowBoardApp(
      settingsRepository: getIt(),
      authCubit: getIt(),
      syncCubit: getIt(),
      router: getIt(),
      notifications: getIt(),
    ),
  );
}
