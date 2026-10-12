import 'dart:async';

import 'package:flowboard/core/di/injector.dart';
import 'package:flowboard/core/router/home_shell.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_form_cubit.dart';
import 'package:flowboard/features/auth/presentation/login_page.dart';
import 'package:flowboard/features/auth/presentation/register_page.dart';
import 'package:flowboard/features/boards/presentation/board_page.dart';
import 'package:flowboard/features/boards/presentation/boards_page.dart';
import 'package:flowboard/features/boards/presentation/card_page.dart';
import 'package:flowboard/features/boards/presentation/cubit/board_cubit.dart';
import 'package:flowboard/features/boards/presentation/cubit/boards_cubit.dart';
import 'package:flowboard/features/boards/presentation/cubit/card_cubit.dart';
import 'package:flowboard/features/comments/presentation/cubit/comments_cubit.dart';
import 'package:flowboard/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:flowboard/features/profile/presentation/profile_page.dart';
import 'package:flowboard/features/settings/presentation/settings_page.dart';
import 'package:flowboard/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:flowboard/features/tasks/presentation/my_tasks_page.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/join_workspace_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/members_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/cubit/workspaces_cubit.dart';
import 'package:flowboard/features/workspaces/presentation/join_workspace_page.dart';
import 'package:flowboard/features/workspaces/presentation/members_page.dart';
import 'package:flowboard/features/workspaces/presentation/workspaces_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const login = 'login';
  static const register = 'register';
  static const join = 'join';

  // Bottom navigation tabs.
  static const home = 'home';
  static const myTasks = 'myTasks';
  static const profile = 'profile';

  static const settings = 'settings';
  static const members = 'members';
  static const boards = 'boards';
  static const board = 'board';
  static const card = 'card';

  /// A card opened outside its board (My tasks, push notifications).
  static const task = 'task';
}

const _authPaths = {'/login', '/register'};

/// Only same-app paths are allowed as a post-login target.
String? _safeFrom(String? from) =>
    from != null && from.startsWith('/') && !from.startsWith('//')
    ? from
    : null;

/// Routes guarded by [auth]. Screen cubits are created from get_it here so
/// widgets stay free of DI lookups.
///
/// Home, My tasks and Profile are tabs of [HomeShell]; boards, cards and
/// settings open full screen on the root navigator above the tabs.
GoRouter createRouter(AuthCubit auth) {
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');
  // Signed in on every route below the redirect.
  String userId() => auth.state.user?.id ?? '';

  Widget cardPage(String cardId) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => CardCubit(
          cardId: cardId,
          cards: getIt(),
          boards: getIt(),
          workspaces: getIt(),
        ),
      ),
      BlocProvider(
        create: (_) => CommentsCubit(
          cardId: cardId,
          currentUserId: userId(),
          comments: getIt(),
        ),
      ),
    ],
    child: const CardPage(),
  );

  return GoRouter(
    navigatorKey: root,
    refreshListenable: _StreamListenable(auth.stream),
    redirect: (context, state) {
      final loggedIn = auth.state.isAuthenticated;
      final onAuthPage = _authPaths.contains(state.matchedLocation);
      if (!loggedIn) {
        if (onAuthPage) return null;
        final target = state.uri.toString();
        return Uri(
          path: '/login',
          queryParameters: target == '/' ? null : {'from': target},
        ).toString();
      }
      if (onAuthPage) {
        return _safeFrom(state.uri.queryParameters['from']) ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (context, state) => BlocProvider(
          create: (_) => AuthFormCubit(getIt()),
          // A new page per query, so "account created" prefills the form.
          child: LoginPage(key: ValueKey(state.uri.query)),
        ),
      ),
      GoRoute(
        path: '/register',
        name: AppRoutes.register,
        builder: (context, state) => BlocProvider(
          create: (_) => AuthFormCubit(getIt()),
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        name: AppRoutes.join,
        builder: (context, state) => BlocProvider(
          create: (_) => _loading(
            JoinWorkspaceCubit(getIt(), state.pathParameters['token']!),
            (c) => c.load(),
          ),
          child: const JoinWorkspacePage(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BlocProvider(
          create: (_) => MyTasksCubit(getIt(), userId: userId()),
          child: HomeShell(shell: shell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: AppRoutes.home,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      _loading(WorkspacesCubit(getIt()), (c) => c.load()),
                  child: const WorkspacesPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'workspaces/:workspaceId',
                    name: AppRoutes.boards,
                    parentNavigatorKey: root,
                    builder: (context, state) => BlocProvider(
                      create: (_) => BoardsCubit(
                        getIt(),
                        getIt(),
                        state.pathParameters['workspaceId']!,
                      ),
                      child: const BoardsPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'members',
                        name: AppRoutes.members,
                        parentNavigatorKey: root,
                        builder: (context, state) => BlocProvider(
                          create: (_) => _loading(
                            MembersCubit(
                              getIt(),
                              state.pathParameters['workspaceId']!,
                            ),
                            (c) => c.load(),
                          ),
                          child: const MembersPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'boards/:boardId',
                        name: AppRoutes.board,
                        parentNavigatorKey: root,
                        builder: (context, state) => BlocProvider(
                          create: (_) => BoardCubit(
                            getIt(),
                            state.pathParameters['boardId']!,
                            currentUserId: userId(),
                          ),
                          child: const BoardPage(),
                        ),
                        routes: [
                          GoRoute(
                            path: 'cards/:cardId',
                            name: AppRoutes.card,
                            parentNavigatorKey: root,
                            builder: (context, state) =>
                                cardPage(state.pathParameters['cardId']!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                name: AppRoutes.myTasks,
                builder: (context, state) => const MyTasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: AppRoutes.profile,
                builder: (context, state) => BlocProvider(
                  create: (_) => _loading(
                    ProfileCubit(getIt(), getIt()),
                    (c) => c.load(),
                  ),
                  child: const ProfilePage(),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: AppRoutes.settings,
                    parentNavigatorKey: root,
                    builder: (context, state) => const SettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/cards/:cardId',
        name: AppRoutes.task,
        builder: (context, state) => cardPage(state.pathParameters['cardId']!),
      ),
    ],
  );
}

/// Starts the initial load without blocking the provider.
T _loading<T>(T cubit, Future<void> Function(T cubit) load) {
  unawaited(load(cubit));
  return cubit;
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
