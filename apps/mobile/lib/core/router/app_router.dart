import 'package:flowboard/features/home/presentation/home_page.dart';
import 'package:flowboard/features/settings/presentation/settings_page.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const home = 'home';
  static const settings = 'settings';
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: AppRoutes.home,
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'settings',
          name: AppRoutes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
