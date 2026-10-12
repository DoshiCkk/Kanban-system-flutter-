import 'dart:async';

import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/theme/app_theme.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';

/// Shows [SplashScreen] while [initialize] runs (database, session restore,
/// push setup), for at least [minimumSplash] so the brand is seen, then
/// builds the app.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.initialize,
    required this.builder,
    this.settings = const AppSettings(),
    this.minimumSplash = const Duration(milliseconds: 1200),
    super.key,
  });

  final Future<void> Function() initialize;
  final WidgetBuilder builder;

  /// Saved theme and language, so the splash already looks like the app.
  final AppSettings settings;
  final Duration minimumSplash;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _ready = Future.wait([
    _initialize(),
    Future<void>.delayed(widget.minimumSplash),
  ]);

  Future<void> _initialize() async {
    try {
      await widget.initialize();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'app start-up',
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      final done = snapshot.connectionState == ConnectionState.done;
      if (done && !snapshot.hasError) return widget.builder(context);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: widget.settings.themeMode,
        locale: widget.settings.language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SplashScreen(failed: snapshot.hasError),
      );
    },
  );
}
