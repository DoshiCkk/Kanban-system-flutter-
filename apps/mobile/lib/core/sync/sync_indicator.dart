import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/sync/sync_cubit.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App bar action showing the sync state; tapping syncs right away.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<SyncCubit, SyncStatus>(
      builder: (context, status) {
        final (IconData icon, String label, Color? color) = switch (status) {
          SyncStatus(phase: SyncPhase.syncing) => (
            Icons.cloud_sync_outlined,
            l10n.syncSyncing,
            null,
          ),
          SyncStatus(phase: SyncPhase.error) => (
            Icons.sync_problem_outlined,
            l10n.syncError,
            scheme.error,
          ),
          SyncStatus(phase: SyncPhase.offline) => (
            Icons.cloud_off_outlined,
            l10n.syncPending(status.pending),
            null,
          ),
          SyncStatus(pending: > 0) => (
            Icons.cloud_upload_outlined,
            l10n.syncPending(status.pending),
            null,
          ),
          _ => (Icons.cloud_done_outlined, l10n.syncSynced, null),
        };
        final pending = status.pending;
        return IconButton(
          key: const ValueKey('sync-indicator'),
          tooltip: label,
          onPressed: () => unawaited(context.read<SyncCubit>().syncNow()),
          icon: Badge(
            isLabelVisible: pending > 0 && status.phase != SyncPhase.syncing,
            label: Text('$pending'),
            child: Icon(icon, color: color, semanticLabel: label),
          ),
        );
      },
    );
  }
}
