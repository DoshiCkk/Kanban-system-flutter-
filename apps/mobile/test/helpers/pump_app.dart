import 'package:flowboard/app.dart';
import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/workspaces/domain/workspaces_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';
import 'in_memory_settings_repository.dart';

class TestApp {
  TestApp({
    required this.auth,
    required this.workspaces,
    required this.settings,
    required this.authCubit,
    required this.router,
  });

  final FakeAuthRepository auth;
  final FakeWorkspacesRepository workspaces;
  final InMemorySettingsRepository settings;
  final AuthCubit authCubit;
  final GoRouter router;
}

/// Pumps the full app (real router + cubits) on top of fake repositories.
Future<TestApp> pumpFlowBoard(
  WidgetTester tester, {
  bool signedIn = true,
  String? initialLocation,
}) async {
  await getIt.reset();
  final auth = FakeAuthRepository(user: signedIn ? testUser : null);
  final workspaces = FakeWorkspacesRepository();
  final settings = InMemorySettingsRepository(
    const AppSettings(language: AppLanguage.en),
  );
  getIt
    ..registerSingleton<AuthRepository>(auth)
    ..registerSingleton<WorkspacesRepository>(workspaces);

  final authCubit = AuthCubit(auth);
  final router = createRouter(authCubit);
  addTearDown(() async {
    router.dispose();
    await authCubit.close();
    await getIt.reset();
  });
  if (initialLocation != null) router.go(initialLocation);

  await tester.pumpWidget(
    FlowBoardApp(
      settingsRepository: settings,
      authCubit: authCubit,
      router: router,
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(
    auth: auth,
    workspaces: workspaces,
    settings: settings,
    authCubit: authCubit,
    router: router,
  );
}
