import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/theme/app_theme.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
import 'package:flowboard/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FlowBoardApp extends StatelessWidget {
  const FlowBoardApp({
    required this.settingsRepository,
    required this.router,
    super.key,
  });

  final SettingsRepository settingsRepository;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(settingsRepository),
      child: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: settings.language.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
  }
}
