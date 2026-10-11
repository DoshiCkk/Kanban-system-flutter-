/// Build-time configuration passed via `--dart-define` or
/// `--dart-define-from-file=config/dev.json`.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.pushEnabled = false});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      // Android emulator alias for the host machine. On the iOS simulator
      // pass http://localhost:3000 instead.
      defaultValue: 'http://10.0.2.2:3000',
    ),
    // Set at build time; the analyzer only sees the default.
    // ignore: avoid_redundant_argument_values
    pushEnabled: bool.fromEnvironment('PUSH_ENABLED'),
  );

  final String apiBaseUrl;

  /// `--dart-define=PUSH_ENABLED=true` once the Firebase config files are in
  /// place (docs/push.md). Off by default: the app runs without push.
  final bool pushEnabled;
}
