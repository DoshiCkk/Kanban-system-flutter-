import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/sync/sync_cubit.dart';
import 'package:flowboard/features/auth/domain/user.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _LogoutChoice { sync, anyway }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  /// Warns when the outbox still holds changes (docs/sync.md §8).
  Future<void> _logout(BuildContext context) async {
    final l10n = context.l10n;
    final auth = context.read<AuthCubit>();
    final sync = context.read<SyncCubit>();
    final pending = sync.state.pending;
    if (pending > 0) {
      final choice = await showDialog<_LogoutChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.logoutUnsyncedTitle(pending)),
          content: Text(l10n.logoutUnsyncedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LogoutChoice.anyway),
              child: Text(l10n.logoutAnyway),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LogoutChoice.sync),
              child: Text(l10n.logoutSyncAndSignOut),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      if (choice == _LogoutChoice.sync && !await sync.syncNow()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.logoutSyncFailed)));
        }
        return;
      }
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    final user = context.select<AuthCubit, User?>((c) => c.state.user);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (user != null) ...[
            _SectionHeader(l10n.settingsAccountSection),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.settingsLogout),
              onTap: () => unawaited(_logout(context)),
            ),
            const Divider(),
          ],
          _SectionHeader(l10n.settingsThemeSection),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) cubit.setThemeMode(mode).ignore();
            },
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(_themeLabel(l10n, mode)),
                  ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsLanguageSection),
          RadioGroup<AppLanguage>(
            groupValue: settings.language,
            onChanged: (language) {
              if (language != null) cubit.setLanguage(language).ignore();
            },
            child: Column(
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: language,
                    title: Text(_languageLabel(l10n, language)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };

  static String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => l10n.languageSystem,
        AppLanguage.en => l10n.languageEnglish,
        AppLanguage.ru => l10n.languageRussian,
        AppLanguage.kk => l10n.languageKazakh,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
