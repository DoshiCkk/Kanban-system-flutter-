import 'package:flowboard/app.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/di/injector.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(AppConfig.fromEnvironment());
  runApp(FlowBoardApp(settingsRepository: getIt(), router: getIt()));
}
