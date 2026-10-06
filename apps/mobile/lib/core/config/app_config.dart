/// Build-time configuration passed via `--dart-define` or
/// `--dart-define-from-file=config/dev.json`.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      // Android emulator alias for the host machine. On the iOS simulator
      // pass http://localhost:3000 instead.
      defaultValue: 'http://10.0.2.2:3000',
    ),
  );

  final String apiBaseUrl;
}
