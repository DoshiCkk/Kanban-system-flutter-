import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/features/tasks/domain/task_groups.dart';
import 'package:flowboard/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation between the three main sections. Each tab keeps its
/// own stack; boards, cards and settings open full screen above it.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overdue = context.select<MyTasksCubit, int>(
      (c) => c.state.count(TaskGroup.overdue),
    );
    // Read as "Overdue: 2, My tasks", not "2, My tasks".
    final overdueCount = Text(
      '$overdue',
      semanticsLabel: '${l10n.taskGroupOverdue}: $overdue',
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again goes back to its start.
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: overdue > 0,
              label: overdueCount,
              child: const Icon(Icons.task_alt_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: overdue > 0,
              label: overdueCount,
              child: const Icon(Icons.task_alt),
            ),
            label: l10n.navMyTasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
